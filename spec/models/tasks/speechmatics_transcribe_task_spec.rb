require 'spec_helper'

describe Tasks::SpeechmaticsTranscribeTask do

  before { StripeMock.start }
  after { StripeMock.stop }

  let(:audio_file) { FactoryGirl.create(:audio_file_private) }
  let(:task) { Tasks::SpeechmaticsTranscribeTask.new(owner: audio_file) }

  let(:response) {
    m = Hashie::Mash.new
    m.body = {
      "speakers" => [
      {
        "duration" => "1.270",
        "name" => "M1",
        "time" => "0.590"
      }
      ],
      "words" => [
      { 
        "duration" => "0.230",
        "name" => "Hello",
        "time" => "0.590"
      },
      { 
        "duration" => "0.070",
        "name" => "World",
        "time" => "0.960"
      },
      { 
        "duration" => "0.000",
        "name" => ".",
        "time" => "1.270"
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
      Utils.should_receive(:download_temp_file).and_return(File.open(test_file('test.mp3')))

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
      puts "trans: #{trans.timed_texts.to_json}"

    end


  end

end
