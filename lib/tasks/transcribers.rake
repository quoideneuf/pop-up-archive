require 'ansi/progressbar'

namespace :transcribers do

  desc "Assign transcriber to transcripts"
  task assign_transcripts: [:environment] do
    print "Calculating transcripts that require updating ..."
    need_updating = Transcript.where(:transcriber_id => nil).count
    puts " #{need_updating}"
    progress = ANSI::Progressbar.new("Transcripts", need_updating, STDOUT)
    progress.bar_mark = '='
    progress.__send__ :show
    transcribers = {
      'Tasks::SpeechmaticsTranscribeTask' => Transcriber.find_by_name('speechmatics'),
      'Tasks::TranscribeTask'             => Transcriber.find_by_name('google_voice'),
    }
    # unscoped to avoid selecting timed_texts, which are JOINed by default.
    Transcript.unscoped.where(:transcriber_id => nil).find_each(:batch_size => 10) do |transcript|
      # find the related audio file, its task, and assign id
      tasks = Task.where(:owner_id => transcript.audio_file_id, :owner_type => 'AudioFile', :status => 'complete')
      tasks.each do |task|
        if transcribers.has_key?(task.type)
          # we don't want to update the parent item.updated_at so run raw sql
          t = transcribers[task.type]
          transcript.connection.execute("update transcripts set transcriber_id=#{t.id},cost_per_min=#{t.cost_per_min},retail_cost_per_min=#{t.retail_cost_per_min} where id=#{transcript.id}")
        end
      end
      progress.inc
      STDOUT.flush
    end
    progress.finish
  end

end
