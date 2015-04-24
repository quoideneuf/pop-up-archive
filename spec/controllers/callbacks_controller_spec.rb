require 'spec_helper'
describe CallbacksController do
  extend ControllerMacros

  before { StripeMock.start }
  after { StripeMock.stop }

  before :each do
    request.accept = "application/json"
  end

  describe "POST 'create'" do
    before :each do
      @task = FactoryGirl.create :add_to_amara_task, extras: {'video_id' => 'abcdefg'}

    end

    it "gets random callback from amara" do
      post 'amara', {"video_id"=>"abcdefg", "event"=>'subs-random'}
      response.code.should eq "200"
      response.should be_success
    end

    it "gets new callback from amara" do
      post 'amara', {"video_id"=>"abcdefg", "event"=>'subs-new'}
      response.code.should eq "202"
      response.should be_success
    end

    it "gets approved callback from amara" do
      post 'amara', {"video_id"=>"abcdefg", "event"=>'subs-approved'}
      response.code.should eq "202"
      response.should be_success
    end

  end

  describe "Stripe callbacks" do

    self.use_transactional_fixtures = false  # so controller actions are not isolated

    it "logs event as ActiveAdminComent on User" do
      # prep fixtures
      user = FactoryGirl.create :user
      # use explicit customer id to avoid confusion
      user.customer_id = 'test_stripe_customer_123'
      user.save!
      stripe_event = {
        data: {
          object: {
            customer: user.customer_id,
          }
        }
      }
      user.save!
 
      # test response and that user is changed in db
      post 'stripe_webhook', stripe_event
      response.code.should eq "200"
      comment = user.active_admin_comments.first
      JSON.parse(comment.body).should eq stripe_event
    end

  end

end
