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
    @file_id    = params[:file_id]
    @audio_file = AudioFile.find(@file_id)
    @mp3        = @audio_file.public_url(extension: :mp3)
    @ogg        = @audio_file.public_url(extension: :ogg)
    @transcript = @audio_file.best_transcript
    @title      = params[:title] || @audio_file.item.title
    @chunk_size = params[:chunk] || 30
    @start      = params[:start] || 0
    @end        = params[:end]   || false
  end
end


