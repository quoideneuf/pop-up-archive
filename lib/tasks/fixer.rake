namespace :fixer do

  desc "check fixer status mismatches"
  task check: [:environment] do

    recover_too = ENV['RECOVER']
    puts "Finding all tasks with status mismatch..."
    puts "Will try to recover them too..." if recover_too
    mismatched_tasks = Task.get_mismatched_status('working')
    mismatched_tasks.each do |task|
      puts "Task #{task.type} #{task.id} has status '#{task.status}' with results: " + task.results.inspect
      if recover_too 
        task.recover!
        puts "Task #{task.type} #{task.id} new status == #{task.status}"
      end
    end

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


  end

end

