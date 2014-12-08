class Tasks::TranscodeTask < Task

  after_commit :create_transcode_job, :on => :create

  def finish_task
    return unless audio_file
    audio_file.check_transcode_complete

    # optimally the length check should be in an analyze task,
    # but we check here too just in case it missed on that step.
    if !audio_file.duration or audio_file.duration == 0
      analysis = self.results[:info] || {}
      if analysis[:length] and analysis[:length].to_i > 0
        Rails.logger.warn "setting audio_file.duration on #{audio_file.id} from transcode task #{self.id}"
        audio_file.update_attribute(:duration, analysis[:length].to_i)
      end
    end
  end

  def recover!
    if !audio_file
      cancel!
    else
      # most often status is working but job has completed,
      # and there's just a timing issue between the db commit and the worker running.
      finish!
    end
  end

  def audio_file
    self.owner
  end

  def format
    extras['format']
  end

  def label
    self.id
  end

  def destination
    extras['destination'] || owner.try(:destination, {
      storage: storage,
      version: format
    })
  end

  def create_transcode_job
    j = create_job do |job|
      job.job_type    = 'audio'
      job.original    = original
      job.priority    = 4
      job.retry_delay = Task::RETRY_DELAY
      job.retry_max   = Task::MAX_WORKTIME / Task::RETRY_DELAY
      job.add_task({
        task_type: 'transcode',
        result:    destination,
        call_back: call_back_url,
        options:   extras,
        label:     label
      })
    end
  end

end
