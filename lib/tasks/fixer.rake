require 'pp'

namespace :fixer do

  desc "check fixer status mismatches"
  task check: [:environment] do

    verbose = ENV['VERBOSE']
    debug   = ENV['DEBUG']
    limit   = ENV['LIMIT']
    recover_types = Hash[ ENV['RECOVER'] ? ENV['RECOVER'].split(/\ *,\ */).map{|t| [t, true]} : [] ]
    debug and pp recover_types.inspect
    puts "Finding all tasks with status mismatch..."
    puts "Will try to recover these types: #{ recover_types.keys.inspect }"
    mismatched_tasks = Task.get_mismatched_status('working')
    mismatched_report = Hash.new{ |h,k| h[k] = 1 }
    mismatched_tasks.each do |task|
      mismatched_report[task.type] += 1
      if limit and limit.to_i <= mismatched_report[task.type]
        debug and puts "Limit #{limit} reached for #{task.type}. Skipping eval of task #{task.id}"
        next
      end
      debug and puts "Task #{task.type} #{task.id} has status '#{task.status}' with results: " + task.results.inspect
      if recover_types.has_key?(task.type)
        verbose and puts "Calling #{task.type}.find(#{task.id}).recover!"
        task.recover!
        verbose and puts "#{task.type}.find(#{task.id}) new status == #{task.status}"
        mismatched_report[task.status] += 1
      end
    end

    puts "These tasks with mismatched status were found:"
    pp mismatched_report
  end

  desc "set duration from any complete transcoding"
  task set_duration: [:environment] do

    print "Finding all audio_file records with nil duration... "
    affected = AudioFile.where('duration is null').count
    puts "found #{affected}"
    fixed = 0
    AudioFile.where('duration is null').find_in_batches do |afgroup|
      afgroup.each do |af|
        af.tasks.each do |task|
          if task.type == "Tasks::TranscodeTask" and task.status == 'complete'
            if task.results and task.results['info'] and task.results['info']['length']
              puts "audio #{af.id} has nil duration, but task #{task.identifier}:#{task.id} has length #{task.results['info']['length']}"
              af.update_attribute(:duration, task.results['info']['length'].to_i)
              fixed += 1
            end
          end
        end
      end
    end
    puts "Updated #{fixed} audio_files"

  end

  desc "speechmatics sanity check"
  task speechmatics_poll: [:environment] do
    # No tasks are recovered by default, since that means notifying the user on success,
    # which we might not want to do in testing/dev. Set RECOVER env var to trigger task.recover!
    ok_to_recover = ENV['RECOVER']
 
    # find all status=created older than N hours
    # and verify they exist at SM. If not, cancel them.
    sm_tasks = Task.where(type: 'Tasks::SpeechmaticsTranscribeTask')\
                   .where('status not in (?)', [Task::CANCELLED,Task::COMPLETE])\
                   .where('created_at < ?', DateTime.now-1)
    sm_tasks_count = sm_tasks.count
    puts "Found #{sm_tasks_count} unfinished Speechmatics tasks older than 1 day"

    report = {'cancelled, no job_id' => 0, 'missing job_id' => 0, 'No SM job found for job_id' => 0, 'recovered' => 0}

    # fetch all SM jobs at once to save HTTP overhead.
    # TODO ask them to implement sorting, searching, paging.
    sm = Speechmatics::Client.new({ :request => { :timeout => 120 } })
    sm_jobs = sm.user.jobs.list.jobs
    # create lookup hash by job id
    sm_jobs_lookup = Hash[ sm_jobs.map{ |smjob| [smjob['id'].to_s, smjob] } ]
    sm_tasks.find_in_batches do |taskgroup|
      taskgroup.each do |task|
        # if we don't have a job_id then it never was created at SM
        if !task.extras['job_id']
          puts "Task.find(#{task.id}) has no job_id: #{task.inspect}"

          # if not recovering, log it and skip to next
          if !ok_to_recover
            report['missing job_id'] += 1
            next
          end

          task.recover!  # should cancel it with err msg if can't reverse lookup job_id
          if task.status == "cancelled"
            report['cancelled, no job_id'] += 1
          elsif task.status == "complete"
            report['recovered'] += 1
          else
            puts "Called Task.find(#{task.id}).recover! and ended with status '#{task.status}'"
          end
          next
        end

        # lookup SM status
        sm_job = sm_jobs_lookup[task.extras['job_id']]
        if !sm_job
          puts "No SM job found for task: #{task.inspect}"
          report['No SM job found for job_id'] += 1
          next
        end

        puts "Task.find(#{task.id}) looks like this at SM: #{sm_job.inspect}"
        if ok_to_recover
          task.recover! && report['recovered'] += 1
        end
         
      end
    end

    report.keys.each do |k|
      puts "#{k} => #{report[k].to_s}"
    end

  end

end

