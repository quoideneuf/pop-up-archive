class Tasks::CopyTask < Task

  attr_accessor :should_process
  @should_process = false

  after_commit :create_copy_job, :on => :create
  after_commit :start_processing, :on => :update

  def finish_task
    return unless owner
    result_path = URI.parse(extras['destination']).path
    new_storage_id = storage_id || extras['storage_id'].to_i

    # set the file on the owner, and the storage as the upload_to
    owner.update_file!(File.basename(result_path), new_storage_id)
    self.should_process = true
  end

  def recover!
    if !owner
      extras['error'] = 'No owner defined'
      cancel!
    elsif !destination_exists?
      extras['error'] = 'Destination URL does not exist'
      cancel!
    else
      finish!
    end
  end

  def destination_exists?
    dest_url = URI.parse(extras['destination'])
    connection = Fog::Storage.new(storage.credentials)
    file_exists?(connection, dest_url)
  end 

  def create_copy_job
    j = create_job do |job|
      job.job_type    = 'audio'
      job.original    = original
      job.retry_delay = Task::RETRY_DELAY
      job.retry_max   = Task::MAX_WORKTIME / Task::RETRY_DELAY
      job.priority    = 1

      job.add_task({
        task_type: 'copy',
        label:     self.id,
        result:    destination,
        call_back: call_back_url
      })
    end
  end

  def start_processing
    return unless should_process
    self.owner(true).process_file
    self.should_process = false
  end

  def destination
    extras['destination'] || owner.try(:destination, {
      storage: storage
    })
  end

end
