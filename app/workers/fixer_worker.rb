# encoding: utf-8

class FixerWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 25

  def perform(job_params)
    begin
      fixer_client = Fixer::Client.new
      new_job = fixer_client.jobs.create({job: job_params}).job
      job_id = new_job.id
    rescue Object=>exception
      logger.error "create_job: error: #{exception.class.name}: #{exception.message}\n\t#{exception.backtrace.join("\n\t")}"
      job_id = 1 
    end 
    job_id
  end

end
