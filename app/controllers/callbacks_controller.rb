class CallbacksController < ApplicationController

  skip_before_filter :verify_authenticity_token

  def amara
    if params[:event] == "subs-approved" || params[:event] == "subs-new"
      # figure out what task this is related to
      if task = Task.where("extras -> 'video_id' = ?", params[:video_id]).first
        FinishTaskWorker.perform_async(task.id) unless Rails.env.test?
      end
      head 202
    else
      head 200
    end
  end

  def fixer
    @resource = params[:model_name].camelize.constantize.find(params[:id])
    if params[:task].present? && @resource.update_from_fixer(params[:task])
      head 202
    else
      head 200
    end    
  end

  def speechmatics
    # find the task that created the speechmatics job.
    # best case is that we have a proper xref in the extras[:job_id]
    # worst case is that we rely on the callback url to contain the task.extras[:public_id]

    # backwards compat.
    if params[:model_name] == 'audio_file'
      af = params[:model_name].camelize.constantize.find(params[:model_id])
      @resource = af.tasks.speechmatics_transcribe.where("extras -> 'job_id' = ?", params[:id]).first
    else
      @resource = Task.where("extras -> 'public_id' = ?", params[:model_id]).first || Task.where("extras -> 'job_id' = ?", params[:id]).first
    end

    if @resource
      if @resource.extras['job_id'] && @resource.extras['job_id'] == params[:id]
        # base case. proper 2-way xref, nothing to do
      elsif !@resource.extras['job_id']
        # worst case. create the job_id now but give it a different key so we can tell it was after-the-fact.
        @resource.extras['sm_job_id'] = params[:id]
      end
      FinishTaskWorker.perform_async(@resource.id) unless Rails.env.test?
      head 202
    else
      head 200
    end    
  
  end

end
