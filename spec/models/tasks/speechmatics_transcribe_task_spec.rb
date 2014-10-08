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
        "duration" => "0.230",
        "name" => "Hello",
        "time" => "0.590",
        "confidence" => "0.995"
      },
      { 
        "duration" => "0.070",
        "name" => "World's",
        "time" => "0.960",
        "confidence" => "0.995"
      },
      { 
        "duration" => "0.000",
        "name" => ".",
        "time" => "1.270",
        "confidence" => "NaN"
      }
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

      trans.timed_texts.count.should == 1
      trans.timed_texts.first.text.should == "Hello World's."

      trans.speakers.count.should == 1
      trans.speakers.first.name.should == "M1"
      trans.timed_texts.first.speaker_id.should == trans.speakers.first.id
    end

    it 'updates paid transcript usage' do
      now = DateTime.now

      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 0
      extras = { 'original' => audio_file.process_file_url, 'user_id' => user.id }
      t = Tasks::SpeechmaticsTranscribeTask.create!(owner: audio_file, identifier: 'test', extras: extras)
      t.user_id.should == user.id.to_s
      t.extras['entity_id'].should == user.entity.id.to_s

      t.update_premium_transcript_usage(now).should == 60
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 60

    end

  end

end
