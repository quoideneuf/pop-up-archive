require 'spec_helper'

describe Utils do
  before { StripeMock.start }
  after { StripeMock.stop }

  it "has a logger" do
    Utils.logger.should_not be_nil
  end

  it "checks http resource exists" do
    Utils.http_resource_exists?('http://www.prx.org/robots.txt').should be_truthy
  end

  it "checks http resource exists, follow redirect" do
    Utils.http_resource_exists?('http://prx.org/robots.txt').should be_truthy
  end

  it "checks http resource and retries" do
    Utils.http_resource_exists?('http://www.prx.org/noway.txt', 2).should be_falsey
  end

  it "downloads a public file to tmp file" do
    url = "https://www.popuparchive.com/assets/prx_logo.png"
    pf = Utils.download_public_file(URI.parse(url))
    pf.size.should == 4128
  end

  it "croaks when unable to download a public file" do
    url = 'http://www.prx.org/noway.txt'
    expect{ Utils.download_public_file(URI.parse(url), 2) }.to raise_error(Exception)
  end

  it "checks for when a url is for an audio file" do
    base = 'http://prx.org/file.'
    Utils::AUDIO_EXTENSIONS.each do |ext|
      Utils.is_audio_file?(base+ext).should be_truthy
    end
  end

  it "checks for when a url is NOT for an audio file" do
    base = 'http://prx.org/file.'
    ['mov', 'doc', 'txt', 'html'].each do |ext|
      Utils.is_audio_file?(base+ext).should_not be_truthy
    end
  end
  
  it "checks for when a url is for an image file" do
    base = 'http://prx.org/file.'
    Utils::IMAGE_EXTENSIONS.each do |ext|
      Utils.is_image_file?(base+ext).should be_truthy
    end
  end

  it "checks for when a url is NOT for an image file" do
    base = 'http://prx.org/file.'
    ['mov', 'doc', 'txt', 'html'].each do |ext|
      Utils.is_image_file?(base+ext).should_not be_truthy
    end
  end

end
