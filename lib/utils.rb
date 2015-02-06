require 'excon'
require 'private_file_not_found'

class Utils


  AUDIO_EXTENSIONS = ['aac', 'aif', 'aiff', 'alac', 'flac', 'm4a', 'm4p', 'mp2', 'mp3', 'mp4', 'ogg', 'raw', 'spx', 'wav', 'wma']
  IMAGE_EXTENSIONS = ['gif', 'png', 'jpg', 'jpeg']
  EXTENSIONS_BY_TYPE = { :audio => AUDIO_EXTENSIONS, :image => IMAGE_EXTENSIONS }

	class<<self

    def logger
      @logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
    end

    def http_resource_exists?(uri, retry_count=10)
      # logger.debug "http_resource_exists?: #{uri}"
      result = false
      try_count = 0
      request_uri = uri.to_s
      while(!result && (try_count < retry_count)) do

        # logger.debug "head: #{request_uri}"
        response = new_connection(request_uri).head(idempotent: true, retry_limit: retry_count)

        # logger.debug "response: #{response.inspect}"

        if response.status.to_s.start_with?('2')
          result = true
        elsif response.status.to_s.start_with?('3')
          # logger.debug "redirect: #{response.headers['Location']}"
          request_uri = response.headers['Location']
        else
          sleep(1)
        end
        try_count += 1
      end

      result
    end

    def head_resp(uri, retry_count=10)
      try_count = 0
      head_resp = nil
      request_uri = uri.to_s
      while(!head_resp && (try_count < retry_count)) do

        # logger.debug "head: #{request_uri}"
        response = new_connection(request_uri).head(idempotent: true, retry_limit: retry_count)

        # logger.debug "response: #{response.inspect}"

        if response.status.to_s.start_with?('2')
          head_resp = response
        elsif response.status.to_s.start_with?('3')
          # logger.debug "redirect: #{response.headers['Location']}"
          request_uri = response.headers['Location']
        else
          sleep(1)
        end 
        try_count += 1
      end 

      head_resp
    end

    def new_connection(uri)
      # turning off ssl check is a Bad Idea, but since some archive.org URLs fail
      # with the check on, and failure is Worse than a Bad Idea, we turn it off.
      # NOTE that the root cause is probably a bad ssl_ca_path at heroku.
      Excon.defaults[:ssl_verify_peer] = false
      Excon.new(uri)
    end

    def get_private_file(connection, uri, retry_count=10)
      bucket = uri.host
      key = uri.path[1..-1]
      file_name = key.split("/").last

      directory = connection.directories.get(bucket)
      if !directory
        raise Exceptions::PrivateFileNotFound.new "Failed to get directory for bucket #{bucket}"
      end

      if !private_file_exists?(connection, uri)
        raise Exceptions::PrivateFileNotFound.new, "File not found on s3: #{bucket}: #{key}"
      end

      result = directory.files.get(key).body

      if result.length <= 0
        raise "Zero length file from: #{uri}"
      end

      result
    end

    def private_file_exists?(connection, uri, retry_count=10)
      bucket = uri.host
      key = uri.path[1..-1]
      file_name = key.split("/").last

      directory = connection.directories.get(bucket)
      if !directory
        raise Exceptions::PrivateFileNotFound.new "Failed to get directory for bucket #{bucket}"
      end

      try_count = 0
      file_exists = false
      while !file_exists && try_count < retry_count
        try_count += 1
        begin
          file_exists = directory.files.head(key)
        rescue Excon::Errors::SocketError => err
          logger.warn "Excon error: #{err} - retrying..."
        rescue Excon::Errors::TemporaryRedirect => err
          logger.warn "Excon error: #{err} - retrying..."
        rescue => err
          raise err # re-throw it if we did not recognize it
        end

        if !file_exists
          sleep(1)
        end
      end
      file_exists
    end

    def download_file(connection, uri, retry_count=10)
      if uri.scheme == 'http' || uri.scheme == 'https'
        download_public_file(uri, retry_count)
      elsif connection
        download_private_file(connection, uri, retry_count)
      end
    end

    def download_private_file(connection, uri, retry_count=10)
      bucket = uri.host
      key = uri.path[1..-1]
      file_name = key.split("/").last

      directory = connection.directories.get(bucket)

      try_count = 0
      file_info = nil

      while !file_info && try_count < 10
        try_count += 1

        logger.info "download_private_file: try: #{try_count}, checking for #{key} in #{bucket}"

        file_info = directory.files.head(key)
        sleep(1) if !file_info
      end

      if !file_info
        raise "File not found: #{bucket}: #{key}"
      end

      try_count = 0
      file_downloaded = false
      temp_file = nil
      while !file_downloaded && try_count < retry_count
        try_count += 1
        begin

          if temp_file
            temp_file.close rescue nil
            temp_file.unlink rescue nil
          end

          temp_file = create_temp_file(file_name)

          directory.files.get(key) do |chunk, remaining_bytes, total_bytes|
            temp_file.write(chunk)
          end

          temp_file.fsync

          if (file_info.content_length != temp_file.size)
            raise "File incorrect size, content_length: #{file_info.content_length}, local file size: #{temp_file.size}"
          end

          file_downloaded = true

        rescue StandardError => err
          logger.error "Private file failed to be retrieved: '#{file_name}': #{err.message}"
        end
        sleep(1)
      end

      if !temp_file
        raise "File download failed, could not download #{key}."
      end

      if (file_info.content_length != temp_file.size)
        raise "File download failed, incorrect size, content_length: #{file_info.content_length}, local file size: #{temp_file.size}"
      end

      if temp_file.size == 0
        raise "Zero length file: #{bucket}: #{key}"
      end

      temp_file
    end

    def download_public_file(uri, retry_count = 10, limit = 10)
      raise 'HTTP redirect too deep' if limit == 0

      try_count = 0
      file_downloaded = false
      temp_file = nil
      redirect_url = nil
      request_uri = uri.to_s

      while !file_downloaded && try_count < retry_count
        try_count += 1
        begin

          file_name = uri.path.split("/").last
          temp_file = create_temp_file(file_name)

          streamer = lambda do |chunk, remaining_bytes, total_bytes|
            temp_file.write(chunk)
          end

          response = new_connection(request_uri).get(:response_block => streamer)
          temp_file.fsync

          logger.debug "#{uri} responded with #{response.status.to_s}"
          if response.status.to_s.start_with?('2')
            file_downloaded = true
          elsif response.status.to_s.start_with?('3')
            redirect_url = response.headers['Location']
          else
            raise "HTTP response error: #{response.inspect}"
          end

          if redirect_url
            # this is imperfect, but deals with odd case where we have spaces in some redirects
            redirect_url = URI.escape(redirect_url) if redirect_url =~ /\s+/
            logger.warn "Got redirect for #{uri} to #{redirect_url}"
            request_uri = redirect_url
            try_count -= 1  # consider this attempt "for free"
          end
        rescue StandardError => err
          logger.error "Public file failed to be retrieved: '#{file_name}': #{err.message}"
          sleep(1)
        end
      end

      if !temp_file or !file_downloaded
        raise "Public file download failed: #{uri}."
      end

      if temp_file.size == 0
        raise "Zero length file: #{temp_file}"
      end

      temp_file
    end

    def create_temp_file(base_file_name=nil, bin_mode=true)
      file_name = File.basename(base_file_name)
      file_ext = File.extname(base_file_name)
      tmp = Tempfile.new([file_name, file_ext])
      tmp.binmode if bin_mode
      tmp
    end

    def is_file_type?(type, url)
      #puts "is_audio_file? url:#{url}"
      begin
        uri = URI.parse(url)
        ext = (File.extname(uri.path)[1..-1] || "").downcase
        EXTENSIONS_BY_TYPE[type].include?(ext)
      rescue URI::BadURIError
        false
      rescue URI::InvalidURIError
        false
      end
    end

    def is_audio_file?(url)
      is_file_type?(:audio, url)
    end
    
    def is_image_file?(url)
      is_file_type?(:image, url)
    end

  end
end
