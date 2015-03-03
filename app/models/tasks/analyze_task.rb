require 'uri'

class Tasks::AnalyzeTask < Task

  after_commit :create_analyze_job, :on => :create

  def finish_task
    return if cancelled?
    if destination && destination.length > 0
      connection = Fog::Storage.new(storage.credentials)
      uri        = URI.parse(destination)
      analysis   = nil
      begin 
        analysis   = get_file(connection, uri)
      rescue Excon::Errors::InternalServerError => err
        # upstream errors are unpredictable, not worth re-trying.
        self.extras['error'] = "Received 500 error for #{uri}"
        self.cancel!
        return
      rescue Exceptions::PrivateFileNotFound => err
        # can't find via our own storage. that's fatal too.
        self.extras['error'] = "Failed to find file: #{err}"
        self.cancel!
        return
      rescue => err
        raise err  # re-throw
      end
      if analysis
        process_analysis(analysis)
      else
        self.extras['error'] = 'No analysis found'
        self.cancel!
        return
      end
      # manually fire prerender cache since we've reached the end of the task workflow.
      owner.item.prerender_cache
    else
      raise "No destination so cannot finish task #{id}"
    end
  end

  def recover!
    if !owner
      extras['error'] = 'No Owner defined'
      cancel!
    elsif !storage
      extras['error'] = 'No Storage defined'
      cancel!
    else
      finish!
    end
  end 

  def process_analysis(analysis_json)
    item = owner.item
    return unless item

    existing_names = item.entities.collect{|e| e.name || ''}.sort.uniq
    analysis = nil
    begin
      if analysis_json.is_a?(String) and analysis_json.length > 0
        analysis = JSON.parse(analysis_json)
      else 
        raise "Got invalid analysis JSON string: #{analysis_json.inspect}"
      end
    rescue JSON::ParserError => err
      # log it and skip
      self.results[:error] = err.to_s
      self.cancel!
      return
    rescue
      raise # re-throw whatever it was
    end

    return unless analysis

    ["entities", "locations", "relations", "tags", "topics"].each do |category|
      analysis[category].each{|analysis_entity|
        name = analysis_entity.delete('name')
        if category == "topics"
          next if (name.blank? || existing_names.include?(name))
          create_entity(name, item, category, analysis_entity)
        elsif category == "tags"
          next if (name.blank? || existing_names.include?(name) || control_the_vocab(name.try(:singularize)))
          create_entity(name.try(:singularize), item, category, analysis_entity)
        else
          next if (name.blank? || existing_names.include?(name) || control_the_vocab(name))
          create_entity(name, item, category, analysis_entity)
        end
      }
    end
  end
  
  def control_the_vocab(term)
    #Check to see if term exists in DBPedia
    results=Dbpedia.search(term).collect(&:label).map(&:downcase)
    !results.include?(term.downcase)
  end
  
  def create_entity(name, item, category, analysis_entity)
    entity = item.entities.build

    entity.category     = category.try(:singularize)
    entity.entity_type  = analysis_entity.delete('type')
    entity.is_confirmed = false
    entity.name         = name
    entity.identifier   = analysis_entity.delete('guid')
    entity.score        = analysis_entity.delete('score')

    # anything left over, put it in the extra
    entity.extra        = analysis_entity
    entity.save
  end

  def create_analyze_job
    j = create_job do |job|
      job.job_type    = 'text'
      job.original    = original
      job.retry_delay = Task::RETRY_DELAY
      job.retry_max   = Task::MAX_WORKTIME / Task::RETRY_DELAY
      job.priority    = 3

      job.add_task({
        task_type: 'analyze',
        label:     self.id,
        result:    destination,
        call_back: call_back_url
      })
    end
  end

  def destination
    extras['destination'] || owner.try(:destination, {
      storage: storage,
      suffix:  '_analysis.json',
      options: { metadata: {'x-archive-meta-mediatype'=>'data' } }
    })
  end

end
