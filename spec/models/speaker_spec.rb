require 'spec_helper'

describe Speaker do


  let(:user) { FactoryGirl.create :user }
  let(:transcript) { FactoryGirl.create :transcript }
  before { StripeMock.start }
  after { StripeMock.stop }

  it "creates a valid speaker" do
    speaker = Speaker.create!(name: 'M1', times: [[0, 120]], transcript: transcript)
  end

end
