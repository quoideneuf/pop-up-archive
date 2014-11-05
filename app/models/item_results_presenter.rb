require 'pp'

class Result; end

class ItemResultsPresenter < BasicObject

  class SearchResult; end

  def initialize(results)
    @results = results.hits
    @facets  = results.facets
  end

  def results
    @_results ||= @results.hits.map {|result|
      ItemResultPresenter.new(result)
    }.select {|r| r.database_object.present? }
  end

  def facets
    @facets
  end

  # ported from the .rabl file to (a) make it easier to write the coercion logic
  # and (b) easier to test
  def format_results
    formatted = []
    attrs = [:title, :description, :date_created, :identifier, :collection_id,
      :collection_title, :episode_title, :series_title, :date_broadcast, :tags, :notes]

    if results and results.size
      results.each do |result|
        fres = { :id => result.id }
        attrs.each do |attr|
          if result.search_attrs[attr].present?
            fres[attr] = result.search_attrs[attr]
          end
        end

        # child objects
        fres[:audio_files] = result.audio_files.map do |af|
          { :url => af.url, :id => af.id, :filename => af.filename }
        end
        fres[:image_files] = result.image_files.map do |imgf|
          { :file => imgf.file, :upload_id => imgf.upload_id, :original_file_url => imgf.original_file_url }
        end
        if result.entities.present?
          fres[:entities] = result.entities.map do |ent|
            { :name => ent.name, :category => ent.category }
          end
        end
        if result.highlighted_audio_files.present?
          fres[:highlights] = {}
          fres[:highlights][:audio_files] = result.highlighted_audio_files.map do |haf|
            { :url => haf.url, :filename => haf.filename, :id => haf.id, :transcript => haf.transcript_array }
          end
        end

        # add to the formatted array
        formatted.push fres
      end
    end
    return formatted
  end

  def respond_to?(method)
    method == :results || @results.respond_to?(method)
  end

  def method_missing(method, *args)
    if @results.respond_to?(method)
      @results.send method, *args
    end
  end

  class ItemResultPresenter < BasicObject

    def initialize(result)
      @result = result['_source']
      @highlight = result.highlight
    end

    def search_attrs
      @result
    end

    def loaded_from_database?
      !!@_result
    end

    def database_object
      # in test env results can be simple in-memory hashes, not db records
      if @result && @result.is_a?(::Item)
        @_result ||= @result
      elsif ::Rails.env.test? and id.match(/^es-mock/)
        @_result ||= ::Item.new()
      else
        @_result ||= ::Item.find_by_id(id)
      end
    end

    def audio_files
      @_audio_files ||= ::AudioFile.where(item_id: @result.id)
    end

    def image_files
      if @_image_files
        @_image_files
      elsif ::ImageFile.where(imageable_id: @result.id, imageable_type: "Item").exists?
        @_image_files = ::ImageFile.where(imageable_id: @result.id, imageable_type: "Item")
      else
        @_image_files = ::ImageFile.where(imageable_id: @result.collection_id, imageable_type: "Collection")
      end
    end

    def highlighted_audio_files
      @_highlighted_audio_files ||= generate_highlighted_audio_files
    end

    def entities
      @_entities ||= build_entities
    end

    def respond_to?(method)
      [:audio_files, :highlighted_audio_files, :entities].include?(method) || @result.respond_to?(method) || database_object.respond_to?(method)
    end

    def method_missing(method, *args)
      if @_result && @result != @_result && search_attrs[method].present?
        return search_attrs[method]
      end

      if loaded_from_database? && database_object.respond_to?(method)
        return database_object.send method, *args
      end

      if @result.respond_to? method
        @result.send method, *args
      elsif database_object.respond_to? method
        database_object.send method, *args
      end
    end

    def class
      ::Result
    end

    private

    def generate_highlighted_audio_files
      if audio_files.size == 0
        return []
      end
      if @highlight.present? && @highlight.transcript.present?
        lookup = ::Hash[@highlight.transcript[0,5].map{|t| [t.gsub(/<\/?em>/, ''), t]}]
      else
        return []
      end
      keys = lookup.keys
      audio_file_presenters = ::Hash.new do |hash, id|
        af = audio_files.find {|af| af.id == id }
        hash[id] = HighlightedAudioFilePresenter.new(af) if af
      end

      if @result.transcripts.present?
        @result.transcripts.select {|transcript| keys.include? transcript.transcript }.each do |transcript|
          audio_file_presenters[transcript.audio_file_id].transcript_array.push({text: lookup[transcript.transcript], start_time: transcript.start_time, end_time: transcript.end_time })
        end
        audio_file_presenters.values
      else
        []
      end
    end

    def build_entities
      [].tap do |results|
        [:confirmed_entities, :high_unconfirmed_entities, :mid_unconfirmed_entities, :low_unconfirmed_entities].each do |ec|
          results.concat @result.send(ec).map {|e| EntityPresenter.new(e) }
        end
      end
    end
  end

  class HighlightedAudioFilePresenter
    attr_reader :id, :url, :filename, :transcript_array, :tasks
    def initialize(audio_file)
      @id = audio_file.id
      @url = audio_file.url
      @filename = audio_file.filename
      @transcript_array = []
    end
  end

  class EntityPresenter
    attr_reader :name, :category, :extra
    def initialize(entity)
      @name = entity.entity
      @category = entity.category
    end

    def class
      ::Entity
    end
  end

end
