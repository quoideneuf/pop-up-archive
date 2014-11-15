require 'spec_helper'

describe Transcriber do

  before { StripeMock.start }
  after { StripeMock.stop }

  before(:all) do
    @transcriber = FactoryGirl.create :transcriber
    @audio       = AudioFile.new  # no factory. no need to save and it saves test time.
  end

  it "should calculate wholesale and retail costs" do

    @audio.duration = 123 
    @audio.premium_retail_cost(@transcriber).should eq 0.20
    @audio.premium_wholesale_cost(@transcriber).should eq 0.10

  end

end
