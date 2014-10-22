require 'utils'
require 'speechmatics'

class Tasks::SpeechmaticsTranscribeTask < Task

  before_validation :set_speechmatics_defaults, :on => :create

  after_commit :create_transcribe_job, :on => :create

  def create_transcribe_job
    ProcessTaskWorker.perform_async(self.id) unless Rails.env.test?
  end

  def process
    # download audio file
    data_file = download_audio_file

    # create the speechmatics job
    sm = Speechmatics::Client.new
    info = sm.user.jobs.create(
      data_file:    data_file.path,
      content_type: 'audio/mpeg; charset=binary',
      notification: 'callback',
      callback:     call_back_url
    )

    # save the speechmatics job reference
    self.extras['job_id'] = info.id
    self.save!

    # update usage if the new job creatd and saved
    update_premium_transcript_usage
  end

  def update_premium_transcript_usage(now=DateTime.now)
    ucalc = UsageCalculator.new(user, now)
    ucalc.calculate(self.class, MonthlyUsage::PREMIUM_TRANSCRIPTS)
  end

  def finish_task
    return unless audio_file

    sm = Speechmatics::Client.new
    transcript = sm.user.jobs(self.extras['job_id']).transcript
    new_trans  = process_transcript(transcript)

    # if new transcript resulted, then call analyze
    if new_trans
      audio_file.analyze_transcript
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

    Transcript.transaction do
      trans    = audio_file.transcripts.create!(
        language: 'en-US',  # TODO get this from audio_file?
        identifier: identifier, 
        start_time: 0, 
        end_time: 0, 
        transcriber_id: transcriber.id,
        cost_per_min: transcriber.cost_per_min
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
            speaker_idx += 1
            tt.save
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
            speaker:    speaker_lookup[speaker['name']]
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
    extras['call_back_url'] = speechmatics_call_back_url
    extras['entity_id']     = user.entity.id if user
    extras['duration']      = audio_file.duration.to_i if audio_file
  end

  def speechmatics_call_back_url
    Rails.application.routes.url_helpers.speechmatics_callback_url(model_name: owner.class.model_name.underscore, model_id: owner.id)
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
    TranscriptCompleteMailer.new_auto_transcript(user, audio_file, audio_file.item).deliver
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
