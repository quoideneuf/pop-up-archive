object transcript

attributes :language

child timed_texts: 'parts' do
  node(:start) {|tt| format_time(tt.start_time) }
  node(:end)   {|tt| format_time(tt.end_time) }
  attribute :text
  attribute :speaker_id
end

child :speakers do |speaker|
  extends 'api/v1/speakers/speaker'
end
