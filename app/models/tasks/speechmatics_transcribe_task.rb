require 'utils'
require 'speechmatics'

class Tasks::SpeechmaticsTranscribeTask < Task

  before_validation :set_speechmatics_defaults, :on => :create

  after_commit :create_transcribe_job, :on => :create

  def create_transcribe_job
    ProcessTaskWorker.perform_async(self.id) unless Rails.env.test?
  end

  def process

    # sanity check -- have we already created a remote request?
    if self.extras['job_id']
      self.extras['log'] = 'process() called on existing job_id'
      return self
    end

    # do we actually have an owner?
    if !owner
      self.extras['error'] = 'No owner/audio_file found'
      self.save!
      return
     end

    # download audio file
    data_file = download_audio_file

    # remember the temp file name so we can look up later
    self.extras['sm_name'] = File.basename(data_file.path)
    self.save!

    # create the speechmatics job
    sm = Speechmatics::Client.new({ :request => { :timeout => 120 } })
    begin
      info = sm.user.jobs.create(
      data_file:    data_file.path,
      content_type: 'audio/mpeg; charset=binary',
      notification: 'callback',
      callback:     call_back_url
      )
      if !info or !info.id
        raise "No job id in speechmatics response for task #{self.id}"
      end

      # save the speechmatics job reference
      self.extras['job_id'] = info.id
      # if we previously had an error, zap it
      if self.extras[:error] == "No Speechmatics job_id found"
        self.extras.delete(:error)
      end
      self.status = :working
      self.save!

    rescue Faraday::Error::TimeoutError => err

      # it is possible that speechmatics got the request
      # but we failed to get the response.
      # so check back to see if a record exists for our file.
      job_id = self.lookup_sm_job_by_name
      if !job_id
        raise "No job_id captured for speechmatics job in task #{self.id}"
      end

    rescue
      # re-throw original exception
      raise
    end

  end

  def lookup_sm_job_by_name

    sm      = Speechmatics::Client.new({ :request => { :timeout => 120 } })
    sm_jobs = sm.user.jobs.list.jobs
    job_id  = nil
    sm_jobs.each do|smjob|
      if smjob['name'] == self.extras['sm_name']
        # yes, it was successful even though SM failed to respond.
        self.extras['job_id'] = job_id = smjob['id']
        self.save!
        break
      end 
    end
    job_id

  end

  def update_premium_transcript_usage(now=DateTime.now)
    billed_user = user
    if !billed_user
      raise "Failed to find billable user with id #{user_id} (#{self.extras.inspect})"
    end

    # call on user.entity so billing goes to org if necessary
    ucalc = UsageCalculator.new(billed_user.entity, now)

    # call on user.entity so billing goes to org if necessary
    billed_duration = ucalc.calculate(Transcriber.premium, MonthlyUsage::PREMIUM_TRANSCRIPTS)

    # call again on the user if user != entity, just to record usage.
    if billed_user.entity != billed_user
      user_ucalc = UsageCalculator.new(billed_user, now)
      user_ucalc.calculate(Transcriber.premium, MonthlyUsage::PREMIUM_TRANSCRIPT_USAGE)
    end

    return billed_duration
  end

  def stuck?
    # cancelled jobs are final.
    return false if status == CANCELLED
    return false if status == COMPLETE

    # older than max worktime and incomplete
    if (DateTime.now.to_time - MAX_WORKTIME).to_datetime.utc > created_at
      return true

    # we failed to register a SM job_id
    elsif !extras['job_id']
      return true

    # process() seems to have failed
    elsif !extras['sm_name']
      return true

    end

    # if we get here, not stuck
    return false
  end

  def recover!

    # easy cases first.
    if !owner
      self.extras[:error] = "No owner/audio_file found"
      cancel!
      return

    # if we have no sm_name, then we never downloaded in prep for SM job
    elsif !self.extras['sm_name']
      self.process()
      return

    elsif !self.extras['job_id']
      # try to look it up, one last time
      if !self.lookup_sm_job_by_name
        self.extras[:error] = "No Speechmatics job_id found"
        cancel!
        return
      end
    end

    # call out to SM and find out what our status is
    sm = Speechmatics::Client.new({ :request => { :timeout => 120 } })
    sm_job = sm.user.jobs(extras['job_id']).get
    self.extras['sm_job_status'] = sm_job.job['job_status']

    # cancel any rejected jobs.
    if self.extras['sm_job_status'] == 'rejected'
      self.extras[:error] = 'Speechmatics job rejected'
      cancel!
      return
    end

    # jobs marked 'expired' may still have a transcript. Only the audio is expired from their cache.
    if self.extras['sm_job_status'] == 'expired' or self.extras['sm_job_status'] == 'done'
      finish!
      return
    end

    # if we get here, unknown status, so log and try to finish anyway.
    logger.warn("Task #{self.id} for Speechmatics job #{self.extras['job_id']} has status '#{self.extras['sm_job_status']}'")
    finish!  # attempt to finish. Who knows, we might get lucky.

  end

  def finish_task
    return unless audio_file

    sm = Speechmatics::Client.new
    transcript = sm.user.jobs(self.extras['job_id']).transcript
    new_trans  = process_transcript(transcript)

    # if new transcript resulted, then call analyze
    if new_trans
      audio_file.analyze_transcript

      # show usage immediately
      update_premium_transcript_usage

      # create audit xref
      self.extras[:transcript_id] = new_trans.id

      # if we previously had an error, zap it
      if self.extras[:error]
        self.extras.delete(:error)
      end

      self.save!

      # share the glad tidings
      notify_user
    end
  end

  def process_transcript(response)
    trans = nil
    return trans if response.blank? || response.body.blank?

    json = response.body.to_json
    identifier = Digest::MD5.hexdigest(json)

    if trans = audio_file.transcripts.where(identifier: identifier).first
      logger.debug "transcript #{trans.id} already exists for this json: #{json[0,50]}"
      return trans
    end

    transcriber = Transcriber.find_by_name('speechmatics')

    # if this was an ondemand transcript, the cost is retail, not wholesale.
    # 'wholesale' is the cost PUA pays, and translates to zero to the customer under their plan.
    # 'retail' is the cost the customer pays, if the transcript is on-demand.
    cost_type = Transcript::WHOLESALE
    if self.extras['ondemand']
      cost_type = Transcript::RETAIL
    end

    Transcript.transaction do
      trans    = audio_file.transcripts.create!(
        language: 'en-US',  # TODO get this from audio_file?
        identifier: identifier,
        start_time: 0,
        end_time: 0,
        transcriber_id: transcriber.id,
        cost_per_min: transcriber.cost_per_min,
        retail_cost_per_min: transcriber.retail_cost_per_min,
        cost_type: cost_type,
      )
      speakers = response.speakers
      words    = response.words

      speaker_lookup = create_speakers(trans, speakers)

      # iterate through the words and speakers
      tt = nil
      speaker_idx = 0
      words.each do |row|
        speaker = speakers[speaker_idx]
        row_end = BigDecimal.new(row['time'].to_s) + BigDecimal.new(row['duration'].to_s)
        speaker_end = BigDecimal.new(speaker['time'].to_s) + BigDecimal.new(speaker['duration'].to_s)

        if tt
          if (row_end > speaker_end)
            tt.save
            speaker_idx += 1
            speaker = speakers[speaker_idx]
            tt = nil
          elsif (row_end - tt[:start_time]) > 5.0
            tt.save
            tt = nil
          else
            tt[:end_time] = row_end
            space = (row['name'] =~ /^[[:punct:]]/) ? '' : ' '
            tt[:text] += "#{space}#{row['name']}"
          end
        end

        if !tt
          tt = trans.timed_texts.build({
            start_time: BigDecimal.new(row['time'].to_s),
            end_time:   row_end,
            text:       row['name'],
            speaker_id: speaker ? speaker_lookup[speaker['name']].id : nil,
          })
        end
      end

      trans.save!
    end
    trans
  end

  def create_speakers(trans, speakers)
    speakers_lookup = {}
    speakers_by_name = speakers.inject({}) {|all, s| all.key?(s['name']) ? all[s['name']] << s : all[s['name']] = [s]; all }
    speakers_by_name.keys.each do |n|
      times = speakers_by_name[n].collect{|r| [BigDecimal.new(r['time'].to_s), (BigDecimal.new(r['time'].to_s) + BigDecimal.new(r['duration'].to_s))] }
      speakers_lookup[n] = trans.speakers.create(name: n, times: times)
    end
    speakers_lookup
  end

  def set_speechmatics_defaults
    extras['public_id']     = SecureRandom.hex(8)
    extras['call_back_url'] = speechmatics_call_back_url
    extras['entity_id']     = user.entity.id if user
    extras['duration']      = audio_file.duration.to_i if audio_file
  end

  def speechmatics_call_back_url
    Rails.application.routes.url_helpers.speechmatics_callback_url(model_name: 'task', model_id: self.extras['public_id'])
  end

  def download_audio_file
    connection = Fog::Storage.new(storage.credentials)
    uri        = URI.parse(audio_file_url)
    Utils.download_file(connection, uri)
  end

  def audio_file_url
    audio_file.public_url(extension: :mp3)
  end

  def notify_user
    return unless (user && audio_file && audio_file.item)
    return if extras['notify_sent']
    r = TranscriptCompleteMailer.new_auto_transcript(user, audio_file, audio_file.item).deliver
    self.extras['notify_sent'] = DateTime.now.to_s
    self.save!
    r
  end

  def audio_file
    owner
  end

  def user
    User.find(user_id) if (user_id.to_i > 0)
  end

  def user_id
    self.extras['user_id']
  end

  def duration
    self.extras['duration'].to_i
  end

  def usage_duration
    # if parent audio_file gets its duration updated after the task was created, for any reason, prefer it
    if duration and duration > 0
      duration
    elsif !audio_file.duration.nil?
      self.extras['duration'] = audio_file.duration.to_s
      audio_file.duration
    else
      duration
    end
  end

end
