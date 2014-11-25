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
          task.extras[:error] = "No SM job found for job_id"
          task.cancel!
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

  desc "check for audio with no transcript and (optionally) create it"
  task transcript_check: [:environment] do

    ok_to_recover = ENV['RECOVER']
    verbose       = ENV['VERBOSE']

    AudioFile.find_in_batches do |afgroup|
      afgroup.each do |af|
        if !af.has_file? && af.original_file_url.blank?
          next  # can't do anything
        end

        if af.transcripts_alone.count >= 2
          next  # has enough
        end

        if af.has_preview? and af.needs_transcript?
          verbose and puts "AudioFile.find(#{af.id}) needs any transcript"
          ok_to_recover and af.process_file # has preview, needs full
        end

        if !af.has_preview? and !af.has_premium_transcript?
          verbose and puts "AudioFile.find(#{af.id}) needs premium transcript"
          ok_to_recover and af.process_file # missing preview
        end

      end # afgroup
    end # batches

  end # task

  desc "resurrect SM jobs marked cancelled but which are really finished"
  task speechmatics_reclaim: [:environment] do
    task_to_job = {
      229896 => 5869,
      231177 => 6270,
      231176 => 6271,
      231174 => 6272,
      231171 => 6273,
      236291 => 6825,
      236289 => 6826,
      261954 => 7455,
      261960 => 7457,
      261933 => 7458,
      261966 => 7459,
      261909 => 7460,
      261950 => 7606,
      261983 => 7611,
      261216 => 11361,
      261884 => 11411,
      261966 => 11418,
      262747 => 11526,
      262742 => 11527,
      262747 => 11528,
      262742 => 11529,
      262747 => 11530,
      262742 => 11531,
      262747 => 11532,
      262742 => 11533,
      262747 => 11534,
      262742 => 11535,
      262747 => 11536,
      262742 => 11538,
      262747 => 11546,
      262996 => 11556,
      262996 => 11557,
      262747 => 11558,
      262996 => 11573,
      262996 => 11576,
      262747 => 11577,
      262996 => 11578,
      262747 => 11580,
      262996 => 11581,
      262996 => 11583,
      262747 => 11586,
      262996 => 11591,
      262996 => 11597,
      262996 => 11611,
      262996 => 11615,
      263554 => 11632,
      263554 => 11634,
      263554 => 11635,
      263554 => 11636,
      263554 => 11637,
      263554 => 11638,
      263554 => 11641,
      263554 => 11643,
      263554 => 11645,
      263554 => 11651,
      263554 => 11659,
      262996 => 11660,
      263554 => 11662,
      263554 => 11664,
      264048 => 11666,
      264048 => 11667,
      264048 => 11668,
      263554 => 11669,
      262996 => 11675,
      264510 => 11757,
      264048 => 11760,
      264545 => 11773,
      264509 => 11774,
      264543 => 11775,
      264545 => 11779,
      264509 => 11780,
      264545 => 11784,
      264545 => 11787,
      263554 => 11805,
      265396 => 11818,
      265955 => 11865,
      266407 => 11904,
      266300 => 11905,
      267579 => 12049,
      267624 => 12053,
      267624 => 12063,
      267640 => 12084,
      267957 => 12177,
      263554 => 12188,
      268525 => 12252,
      269090 => 12326,
      269435 => 12352,
      269446 => 12361,
      269476 => 12371,
      269468 => 12372,
      269494 => 12374,
      269467 => 12380,
      270294 => 12497,
      270294 => 12501,
      270294 => 12502,
      271449 => 12643,
      271473 => 12645,
      271507 => 12659,
      274464 => 12969,
      274465 => 12970,
      274463 => 12973,
      274470 => 12976,
      274548 => 12983,
      274553 => 12985,
      274733 => 13005,
      274860 => 13029,
      274871 => 13033,
      277785 => 13336,
      264133 => 13673,
      278104 => 13695,
      264129 => 13703,
      277777 => 13705,
      277851 => 13712,
      277784 => 13713,
      278541 => 13816,
      278137 => 13867,
      278133 => 13870,
      278135 => 13871,
      278116 => 13881,
      277779 => 13882,
      278124 => 13888,
      278122 => 13889,
      278129 => 13896,
      278120 => 13898,
      278125 => 13899,
      278112 => 13908,
      278127 => 13910,
      278131 => 13912,
      278110 => 13916,
      278109 => 13917,
    }
    task_to_job.keys.each do |task_id|
      job_id = task_to_job[task_id]
      task = Task.find task_id
      if task
        task.extras['job_id'] = job_id
        task.recover!
      end
    end

  end

end

