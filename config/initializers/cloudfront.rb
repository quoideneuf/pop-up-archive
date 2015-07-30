unless Rails.env.test?

Aws::CF::Signer.configure do |config|
  # mangle our env var to get it into expected key syntax
  priv_key = ENV['CLOUDFRONT_KEY'].gsub('"', '').gsub(/\\n/, "\n")
  config.key          = priv_key
  config.key_pair_id  = ENV['CLOUDFRONT_KEY_PAIR_ID']
  config.default_expires = 3600 # 1hr as seconds
end

# monkey patches via 
# http://stackoverflow.com/questions/9956712/use-cdn-with-carrierwave-fog-in-s3-cloudfront-with-rails-3-1
module CarrierWave
  module Uploader
    module Url
      extend ActiveSupport::Concern
      include CarrierWave::Uploader::Configuration
      include CarrierWave::Utilities::Uri

      ##
      # === Parameters
      #
      # [Hash] optional, the query params (only AWS)
      #
      # === Returns
      #
      # [String] the location where this file is accessible via a url
      #
      def url(options = {})
        if file.respond_to?(:url) and not file.url.blank?
          file.method(:url).arity == 0 ? Aws::CF::Signer.sign_url(file.url) : Aws::CF::Signer.sign_url(file.url(options))
        elsif file.respond_to?(:path)
          path = encode_path(file.path.gsub(File.expand_path(root), ''))

          if host = asset_host
            if host.respond_to? :call
              Aws::CF::Signer.sign_url("#{host.call(file)}#{path}")
            else
              Aws::CF::Signer.sign_url("#{host}#{path}")
            end
          else
            Aws::CF::Signer.sign_url((base_path || "") + path)
          end
        end
      end
    end # Url
  end # Uploader
end # CarrierWave

require "fog"

module CarrierWave
  module Storage
    class Fog < Abstract
       class File
          include CarrierWave::Utilities::Uri
          def url
             # Delete 'if statement' related to fog_public
             public_url
          end
       end
    end
  end
end

end # do not run in test mode
