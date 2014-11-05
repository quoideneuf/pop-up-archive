require 'spec_helper'

describe Tasks::SpeechmaticsTranscribeTask do

  before { StripeMock.start }
  after { StripeMock.stop }

  let(:user) { FactoryGirl.create :user }
  let(:audio_file) { FactoryGirl.create(:audio_file_private) }
  let(:task) { Tasks::SpeechmaticsTranscribeTask.new(owner: audio_file, extras: {'user_id' => user.id}) }

  let(:response) {
    m = Hashie::Mash.new
    m.body = {
      "format" => "1.0",
      "job" => {
        "created_at" => "Tue Jul 29 17:12:52 2014",
        "duration" => 2,
        "id" => 843,
        "lang" => "en-US",
        "name" => "npr_336167091.mp3",
        "user_id" => 40
      },
      "speakers" => [
      {
        "duration" => "0.680",
        "name" => "M1",
        "time" => "0.590",
        "confidence" => nil
      }
      ],
      "words" => [
      {
        "duration" => "0.160", 
        "confidence" => "0.995", 
        "name" => "Why", 
        "time" => "0.470"
      }, 
      {
        "duration" => "0.290", 
        "confidence" => "0.995", 
        "name" => "hidy-ho", 
        "time" => "0.630"
      },  
      {
        "duration" => "0.100", 
        "confidence" => "0.995", 
        "name" => "says", 
        "time" => "0.920"
      }, 
      {
        "duration" => "0.180", 
        "confidence" => "0.995", 
        "name" => "world's", 
        "time" => "1.020"
      }, 
      {
        "duration" => "0.120", 
        "confidence" => "0.995", 
        "name" => "C.E.O.", 
        "time" => "1.040"
      }, 
      {
        "duration" => "0.120", 
        "confidence" => "0.995", 
        "name" => "overlord", 
        "time" => "1.060"
      },
      {
        "duration" => "0.000", 
        "confidence" => "NaN", 
        "name" => ".", 
        "time" => "1.060"
      }, 
      ]
    }
    m.speakers = m.body.speakers
    m.words = m.body.words
    m
  }

  context "create job" do


    it "has audio_file url" do
      url = task.audio_file_url
    end

    it "downloads audio_file" do
      task.set_task_defaults
      audio_file.item.token = "untitled.NqMBNV.popuparchive.org"
      Utils.should_receive(:download_file).and_return(File.open(test_file('test.mp3')))

      data_file = task.download_audio_file
      data_file.should_not be_nil
      data_file.is_a?(File).should be_true
    end

    it "makes callback url" do
      task.set_speechmatics_defaults
      task.call_back_url.should eq "http://test.popuparchive.com/speechmatics_callback/files/audio_file/#{audio_file.id}"
    end

    it "processes transcript result" do
      
      trans = task.process_transcript(response)
      # puts trans.timed_texts.to_yaml

      trans.timed_texts.count.should == 1
      trans.timed_texts.first.text.should == "Why hidy-ho says world's C.E.O. overlord."

      trans.speakers.count.should == 1
      trans.speakers.first.name.should == "M1"
      trans.timed_texts.first.speaker_id.should == trans.speakers.first.id
    end

    it 'updates paid transcript usage' do
      now = DateTime.now

      # test user must own the collection, since usage is limited to billable ownership.
      audio_file.item.collection.set_owner(user)

      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 0
      extras = { 'original' => audio_file.process_file_url, 'user_id' => user.id }
      t = Tasks::SpeechmaticsTranscribeTask.create!(owner: audio_file, identifier: 'test', extras: extras)
      
      # audio_file must have the transcript, since transcripts are the billable items.
      audio_file.transcripts << t.process_transcript(response)

      t.user_id.should == user.id.to_s
      t.extras['entity_id'].should == user.entity.id.to_s
      t.update_premium_transcript_usage(now).should == 60
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 60

    end

    it "assigns retail cost for ondemand" do
      audio_file.item.collection.set_owner(user)
      extras = { 'original' => audio_file.process_file_url, 'user_id' => user.id, 'ondemand' => true }
      t = Tasks::SpeechmaticsTranscribeTask.create!(owner: audio_file, identifier: 'test', extras: extras)
      trans = t.process_transcript(response)
      trans.cost_type.should == Task::RETAIL
      trans.cost_per_min.should == Transcriber.find_by_name('speechmatics').retail_cost_per_min
    end

    it 'delineates usage for User vs Org' do
      now = DateTime.now

      # assign user to an org
      org = FactoryGirl.create :organization
      user.organization = org
      user.save!  # because Task will do a User.find(user_id)

      # org must own the collection, since usage is limited to billable ownership.
      audio_file.item.collection.set_owner(org)

      # user must have access to the collection to act on it
      user.collections << audio_file.item.collection

      # user must own the audio_file, since usage is tied to user_id
      audio_file.set_user_id(user.id)
      audio_file.save!  # because usage calculator queries db

      # make sure we start clean
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 0
      extras = { 'original' => audio_file.process_file_url, 'user_id' => user.id }
      t = Tasks::SpeechmaticsTranscribeTask.create!(owner: audio_file, identifier: 'test', extras: extras)
    
      # audio_file must have the transcript, since transcripts are the billable items.
      audio_file.transcripts << t.process_transcript(response)

      #STDERR.puts "task.extras = #{t.extras.inspect}"
      #STDERR.puts "audio       = #{audio_file.inspect}"
      #STDERR.puts "org         = #{org.inspect}"
      #STDERR.puts "user        = #{user.inspect}"
      #STDERR.puts "user.entity = #{user.entity.inspect}"
      t.user_id.should == user.id.to_s
      t.extras['entity_id'].should == user.entity.id.to_s
      t.update_premium_transcript_usage(now).should == 60

      #STDERR.puts "user.monthly_usages == #{user.monthly_usages.inspect}"
      #STDERR.puts "org.monthly_usages  == #{org.monthly_usages.inspect}"

      # user has non-billable usage
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPT_USAGE).should == 60

      # user has zero billable usage
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 0

      # org has all the billable usage
      org.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 60

    end

  end

end
