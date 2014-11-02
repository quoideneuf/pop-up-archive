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
      if limit and limit.to_i >= mismatched_report[task.type]
        debug and puts "Limit #{limit} reached. Skipping eval of task #{task.id}"
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
    # find all status=created older than N hours
    # and verify they exist at SM. If not, cancel them.

  end

end

