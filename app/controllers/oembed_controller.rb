class OembedController < ApplicationController

  rescue_from ActiveRecord::RecordNotFound, :with => :not_found

  def show
    # :url param is required
    if !params[:url]
      render :text => { :error => "not found", :status => 404 }.to_json, :status => :not_found
      return
    end

    # templates handle jsonp response, if necessary.
    @callback = params[:callback]

    # extract the asset from the url
    route_action = Rails.application.routes.recognize_path(params[:url])
    Rails.logger.warn( route_action.inspect )
    if route_action[:action] == 'tplayer'
      # set up instance vars based on :url
      @url        = params[:url]
      @embed      = true
      @file_id    = route_action[:file_id]
      @audio_file = AudioFile.find(@file_id)
      @mp3        = @audio_file.public_url(extension: :mp3)
      #@ogg        = @audio_file.public_url(extension: :ogg)
      @transcript = @audio_file.best_transcript
      @title      = route_action[:title] || @audio_file.item.title
      @chunk_size = route_action[:chunk] || 30
      @start      = route_action[:start] || 0
      @end        = route_action[:end]   || false
      @height     = params[:maxheight] || 400
      @width      = params[:maxwidth]  || 400

      # path to html (rich) template partial
      @partial_path = 'oembed/tplayer.html'
      
      # response type for tplayer
      @type = "rich" 
    end

    respond_to do |format|
      format.html {
        render :formats => [:json], :content_type => "application/json"
      }
      format.json {
        render :formats => [:json]
      }
      format.xml {
        render :formats => [:xml]  # TODO
      }
      format.all {
        render :json => { :error => "Format not implemented", :status => 501 }.to_json, :status => 501
      }
    end

  end

end
