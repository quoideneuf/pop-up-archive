require 'spec_helper'

describe Transcriber do

  before(:all) do
    @transcriber = FactoryGirl.create :transcriber
    @audio       = FactoryGirl.create :audio_file
  end

  it "should calculate wholesale and retail costs" do

    @audio.duration = 123 # 2:03 rounds to 2 min
    @audio.premium_retail_cost(@transcriber).should eq 0.2
    @audio.premium_wholesale_cost(@transcriber).should eq 0.1

  end

end
