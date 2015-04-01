# encoding: utf-8
require 'mixpanel-ruby'

class MixpanelWorker
  include Sidekiq::Worker

  sidekiq_options retry: 10, backtrace: true

  def perform(event_name, events_args)
    begin
      tracker = Mixpanel::Tracker.new(ENV['MIXPANEL_PROJECT'])
      tracker.track(rand(9999), event_name, event_args)
    rescue => e
      raise e
    end
    true
  end

end
