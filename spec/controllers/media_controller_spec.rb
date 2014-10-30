require 'spec_helper'
require 'uri'
describe MediaController do
  extend ControllerMacros

  before { StripeMock.start }
  after { StripeMock.stop }

  describe "GET /media" do

    it "/media route should match" do
      af = FactoryGirl.create :audio_file
      url = af.public_url()
      path = URI(url).path
      #STDERR.puts "audio_file #{af.id} => #{path}"
      expect(:get => path).to route_to(
        :controller => 'media',
        :action    => 'show',
        :token     => af.public_url_token,
        :expires   => "0",
        :use       => "public",
        :class     => "audio_file",
        :id        => af.id.to_s,
        :name      => "test",
        :extension => "mp3"
      ) 
    end

    it "/media route should match with filename with dots in it" do
      af = FactoryGirl.create :audio_file
      af.update_file!('foo.bar.dots.mp3', 0)
      url = af.public_url()
      path = URI(url).path
      #STDERR.puts "audio_file #{af.id} => #{path}"
      expect(:get => path).to route_to(
        :controller => 'media',
        :action    => 'show',
        :token     => af.public_url_token,
        :expires   => "0",
        :use       => "public",
        :class     => "audio_file",
        :id        => af.id.to_s,
        :name      => "foo-bar-dots",
        :extension => "mp3"
      )
    end

  end

end

