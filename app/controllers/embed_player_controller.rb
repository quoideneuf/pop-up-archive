class EmbedPlayerController < ApplicationController
  def show
    @name=params[:name]
    @file_id=params[:file_id]
    @item_id=params[:item_id]
    @collection_id=params[:collection_id]
    @mp3 = AudioFile.find(params[:file_id]).public_url(extension: :mp3)
    @ogg = AudioFile.find(params[:file_id]).public_url(extension: :ogg)
  end

  # embedable player with transcript
  def tplayer
    @embed      = params[:embed] ? true : false
    @file_id    = params[:file_id]
    @audio_file = AudioFile.find(@file_id)
    @mp3        = @audio_file.public_url(extension: :mp3)
    @ogg        = @audio_file.public_url(extension: :ogg)
    @transcript = @audio_file.best_transcript
    @title      = params[:title] || @audio_file.item.title
    @chunk_size = params[:chunk] || 30
    @start      = params[:start] || 0
    @end        = params[:end]   || false

    respond_to do |format|
      format.html {
        render :formats => [:html]
      }
      format.json {
        render :json => {
          file_id: @file_id,
          ogg:     @ogg,
          mp3:     @mp3,
          title:   @title,
          start:   @start,
          end:     @end
        }.to_json, :callback => params[:callback]
      }
    end
  end

end


