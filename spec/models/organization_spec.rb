require 'spec_helper'

describe Organization do
  before { StripeMock.start }
  after { StripeMock.stop }
  
  it "can have collections" do
    @organization = FactoryGirl.create :organization
    @organization.collections << FactoryGirl.create(:collection)
    @organization.collections.count.should eq 1
  end

end
