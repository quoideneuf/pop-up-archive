class Tasks::AnalyzeAudioTask < Task

  after_commit :create_analyze_job, :on => :create

  def finish_task
    super
    return unless audio_file
    return if cancelled?
    analys = self.analysis || {}
    raise "Analysis does not include length: #{self.id}, results: #{analys.inspect}" unless analys[:length]
    audio_file.update_attribute(:duration, analys[:length].to_i)
  end

  def recover!
    # most often status is 'working' but job has completed,
    # and there's just a timing issue in the db save and the worker running.
    # other times, the owner has been deleted.
    if !audio_file
      self.extras[:error] = "No owner/audio_file found"
      cancel!
    else

      # if there is no analysis or analysis.length then finish_task will fail,
      # so just cancel and log error
      analys = self.analysis
      if !analys or !analys[:length]
        if !self.original
          self.extras[:error] = "No original URL and no analysis"
          self.cancel!
          return
        else
          self.extras[:error] = "Analysis does not include length: #{self.id}, results: #{analys.inspect}"
          self.cancel!
          return
        end
      end

      finish!
    end 
  end 

  def analysis
    self.results[:info]
  end

  def create_analyze_job
    j = create_job do |job|
      job.job_type    = 'audio'
      job.original    = original
      job.retry_delay = 3600 # 1 hour
      job.retry_max   = 24 # try for a whole day
      job.priority    = 3

      job.add_task({
        task_type: 'analyze',
        label:     self.id,
        call_back: call_back_url
      })
    end
  end

  def audio_file
    self.owner
  end

end
