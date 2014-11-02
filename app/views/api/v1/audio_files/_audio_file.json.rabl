attributes :id, :filename, :transcoded_at, :duration
attributes :urls => :url
attributes :transcript_type

child timed_transcript: 'transcript' do |t|
  extends 'api/v1/transcripts/transcript'
end

child tasks: 'tasks' do |c|
  extends 'api/v1/tasks/task'
end

if current_user
  node(:original, :if => lambda { |af| can?(:manage, af) }) do |af|
    af.url
  end
end