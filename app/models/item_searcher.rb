require 'stopwords/snowball/filter'
require 'lucene_query_parser'
require 'erb'

class ItemSearcher
  include ERB::Util

  attr_accessor :params, :query_str, :sort_by, :filters, :page, :def_op, :results, :similar_results, :stopped_words, :alt_query

  MIN_FIELDS = ['id', 'title', 'collection_title', 'coll_categories', 'network', 'tags', 'image_url', 'audio_files']

  def initialize(params)
    @params    = params
    @query_str = params[:q] || params[:query]
    @sort_by   = params[:sort_by]
    @sort_order = params[:sort_order]
    if params[:s]
      sstr = params[:s].split /\ +/
      @sort_by = sstr[0]
      @sort_order = sstr[1]
    end
    @filters   = params[:f] || params[:filters]
    @page      = params[:page].to_i
    @size      = params[:size]
    @from      = params[:from]
    @def_op    = params[:op] || 'AND'
    @current_user = params[:current_user] || nil
    @debug     = params[:debug]
    @include_related = params[:related]

    # operator may only be AND or OR
    if @def_op != 'AND' && @def_op != 'OR'
      @def_op = 'AND'
    end

    filter_query_string  # prefilter

  end

  def has_stopped_words?
    @stopped_words && @stopped_words.size > 0
  end

  def has_filters?
    @filters && @filters.size > 0
  end

  def alt_query_encoded
    url_encode(alt_query)
  end 

  # basic search
  # returns ES Response object.
  def search
    query_dsl = prep_search_query
    if @size && @from
      @results = Item.search(query_dsl.to_json, { :size => @size.to_i, :from => @from.to_i })
    else
      @results = Item.search(query_dsl.to_json).page(@page)
    end
    prep_search_results
    @results
  end

  # like search() only pared-down response with no transcripts.
  def simple_search
    query_dsl = prep_search_query
    query_dsl[:_source] = { include: MIN_FIELDS }
    if @size && @from
      @results = Item.search(query_dsl.to_json, { :size => @size.to_i, :from => @from.to_i })
    else
      @results = Item.search(query_dsl.to_json).page(@page)
    end
  end

  # returns suggestions in specialized Hash with autocomplete and item matches
  def suggest
    query_dsl = prep_suggest_query
    sugg_resp = Item.search(query_dsl.to_json).response
    @results  = prep_suggest_results(sugg_resp)
  end

  # get results similar to item_id. basic search, assumes query provided.
  # returns ES Response object.
  # example:
  #  response = ItemSearcher.new({q: query_str}).similar_to_item(123)
  # this method is called internally from Item.find_similar().
  def similar_to_item(item_id, full_result)
    query_dsl = prep_similar_item_query(item_id, full_result)
    if @size && @from
      @results  = Item.search(query_dsl.to_json, { :size => @size.to_i, :from => @from.to_i })
    else
      @results  = Item.search(query_dsl.to_json)
    end
    prep_similar_item_results
    @results
  end

  # returns ES Response object similar to search() results.
  # example:
  #  similar_results = ItemSearcher.new({q: 'foo bar'}).similar
  # same as calling:
  #  searcher = ItemSearcher.new({q: 'foo bar'})
  #  search_results = searcher.search
  #  similar_results = searcher.similar
  # This method uses the ES More Like This API 
  # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-mlt-query.html
  def similar(n=nil)
    # execute search if it hasn't been already
    @results ||= simple_search
    query_dsl = prep_similar_query_query
    if n
      @similar_results = Item.search(query_dsl.to_json, { :size => n.to_i, :from => 0 })
    elsif @size && @page
      @similar_results = Item.search(query_dsl.to_json, { :size => @size.to_i, :from => @from.to_i })
    else
      @similar_results = Item.search(query_dsl.to_json).page(@page)
    end
    prep_similar_query_results
    @similar_results 
  end

  # similar + simple_search = pared-down response size.
  def simple_similar
    @results ||= simple_search
    query_dsl = prep_similar_query_query
    query_dsl[:_source] = { include: MIN_FIELDS }
    if @size && @from
      @similar_results = Item.search(query_dsl.to_json, { :size => @size.to_i, :from => @from.to_i })
    else
      @similar_results = Item.search(query_dsl.to_json).page(@page)
    end
    prep_similar_query_results
    @similar_results
  end

  private

  def prep_suggest_query
    fields = ['collection_title', 'title', 'description', 'coll_category_ci', 'network', 'tag']
    query = {
      bool: {
        must:   { multi_match: { query: @query_str, operator: 'OR', fields: fields, } },
        should: { multi_match: { query: @query_str, fields: fields, type: 'phrase', boost: 10, } },
      }
    }
    suggest = {
      text: @query_str,
    }
    fields.each do |f|
      term_k = f + '_term'
      phrase_k = f + '_phrase'
      suggest[term_k] = { term: { field: f, suggest_mode: 'always', max_edits: 2, prefix_length: 3 } }
      suggest[phrase_k] = {
        phrase: {
          highlight: {
            post_tag: "</em>",
            pre_tag: "<em>"
          },
          field: f,
          real_word_error_likelihood: 0.95,
          max_errors: 0.5,
          direct_generator: [{field: f, min_word_length: 1, suggest_mode: "always"}],
          gram_size: 2
        }
      }
    end
    searchq = Search.new(Item.index_name).to_hash
    searchq[:query] = query
    searchq[:suggest] = suggest
    searchq[:highlight] = { fields: Hash[ fields.map {|f| [f, { number_of_fragments: 0 }] } ] }
    # reduce payload size since we do not need entire doc
    searchq[:_source] = { include: ['id', 'title', 'collection_title', 'collection_id', 'coll_categories', 'network', 'tags'] }
    searchq
  end

  def prep_similar_item_query(item_id, full_result)
    # we assume query has been already crafted by the caller,
    # so we just tweek the usual search to limit the response size and filter out the original item.
    searchq = prep_search_query
    searchq[:filter] = { bool: { must: searchq[:filter], must_not: { term: { id: item_id } } } }
    searchq.delete :highlight  # transcript not included
    if full_result != true
      searchq[:_source] = { include: MIN_FIELDS }
    end
    searchq
  end

  def prep_similar_query_query
    # use the first page of search results as the comparison set
    item_ids = @results.map { |r| r.id }
    searchq = prep_search_query
    searchq[:query] = { 
      :mlt => {
        :fields => ['tag', 'entity', 'coll_categories', 'network'],
        :ids    => item_ids,
        # TODO play with these settings to hit a sweet spot.
        # in general, the more data we have in the index, the higher the numbers can be.
        :boost_terms => 4,
        :boost => 2.0,
        :percent_terms_to_match => 0.2,
        :min_term_freq => 1,
        :min_doc_freq  => 1,
        #:max_query_terms => 20,  # TODO play with this
      }
    }
    # ES requires a query string if no ids are defined
    searchq[:query][:mlt][:like_text] = @query_str if item_ids.size == 0
    #searchq[:explain] = true  # helpful when debugging match/scoring
    searchq
  end

  def prep_search_query
    query_builder = QueryBuilder.new({
      :op      => @def_op,
      :query   => @query_str,
      :sort_by => @sort_by,
      :sort_order => @sort_order,
      :filters => @filters,
      :page    => @page.to_s,
    }, @current_user)

    has_sort = @sort_by && @sort_order

    search_query = Search.new(Item.index_name) do

      query_builder.query do |q|
        #Rails.logger.warn "q=#{q.inspect}"
        query &q
      end

      query_builder.facets do |my_facet|
        # TODO re-enable when we have plans to use facets
        #facet my_facet.name, &my_facet
      end

      query_builder.filters do |my_filter|
        filter my_filter.type, my_filter.value
      end

      # determine sort order
      has_query = nil
      if query_builder.params[:query]
        #STDERR.puts "query_build.params.query == #{query_builder.params[:query]}"
        has_query = query_builder.params[:query]
      end
      if has_sort
        sort do
          by query_builder.sort_column, query_builder.sort_order
        end
      elsif !has_query
        #Rails.logger.warn "no query defined -- sort date_created desc"
        sort do
          by 'date_created', 'desc'
        end
      else
        sort do
          by '_score', 'desc'
        end
      end

      highlight Hash[ ['transcript', 'title', 'description'].map {|f| [f, { number_of_fragments: 0 }] } ]
    end

    # for queries with no 
    #  * explicit fields named (:=) (i.e. most of them),
    #  * wildcards (*)
    #  * phrases (")
    # construct our tuned combined query by hand.
    # TODO would be nice if query_builder could do this for us.
    sq_hash = search_query.to_hash
    if @query_str && !@query_str.match(/["=:\*]/)
      fields = ['title^2', 'description', 'tag', 'entity', 'transcript', 'collection_title', 'coll_category_ci']
      multiquery = { bool: {
        must:   { multi_match: { query: @query_str, operator: @def_op, fields: fields, tie_breaker: 20.0 } },
        should: { multi_match: { query: @query_str, fields: fields, type: 'phrase', boost: 10.0, tie_breaker: 0.5 } },
      } }
      sq_hash[:query] = multiquery
      #sq_hash[:explain] = true
      #logger.warn("after query: #{sq_hash.inspect}")
      #logger.warn(" json query: #{sq_hash.to_json}")
    end

    sq_hash
  end

  # apply some simple filtering to query string
  # for characters we do not support from users.
  # this is a subset of 
  # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html#_reserved_characters
  def filter_query_string
    return unless @query_str.present?
    # try parsing. if we can't, then strip characters.
    # this allows for savvy users to actually exercise features, w/o penalizing inadvertent strings.
    parser = self.class.get_query_parser
    errloc = parser.error_location(@query_str)
    if errloc
      @query_str.gsub!(/[\&\|\>\<\!\(\)\{\}\[\]\^\~\\\/\,]+/, '')
      @query_str.gsub!(/\ +/, ' ')  # reduce multiple spaces to singles
      # if we have just a single double quote mark, strip it too
      if @query_str.match(/"/) and !@query_str.match(/".+?"/)
        @query_str.gsub!(/"/, '')
      end
    end
    @query_str = remove_stop_words(@query_str)
  end

  def self.get_query_parser
    LuceneQueryParser::Parser.new :term_re => "\\p\{Word\}\\.\\*\\-\\'"
  end

  def remove_stop_words(qstr)
    # parse into tree structure
    parser = self.class.get_query_parser
    tree   = parser.parse(qstr)

    # iterate and remove stopwords
    stopped = []
    clauses = []
    alt_clauses = []
    stopword_filter = Stopwords::Snowball::Filter.new "en"

    # TODO use real Parslet::Transform class on this instead of these closures

    serialize_term = lambda do |node|
      if stopword_filter.stopword? node[:term].str.downcase
        stopped.push node[:term].str
        return
      end
      str = []
      if node.has_key? :op
        str.push node[:op].str + ' '
      end
      if node.has_key? :field
        str.push node[:field].str + ':'
      end
      str.push node[:term].str
      clauses.push str.join('')
    end

    serialize_alt_term = lambda do |node|
      is_stop = stopword_filter.stopword? node[:term].str.downcase
      str = []
      if node.has_key? :op 
        str.push node[:op].str + ' ' 
      end 
      if node.has_key? :field
        str.push node[:field].str + ':' 
      end
      if is_stop
        str.push %{"#{node[:term].str}"}
      else
        str.push node[:term].str
      end
      alt_clauses.push str.join('')
    end

    serialize_phrase = lambda do |node|
      str = []
      if node.has_key? :op
        str.push node[:op].str + ' '
      end
      if node.has_key? :field
        str.push node[:field].str + ':' 
      end
      # only double-quote multi-term phrases since we do not want to bias
      # scoring weights for stopwords
      if node[:phrase].str.match(/\ /)
        str.push %{"#{node[:phrase].str}"}
      else
        str.push node[:phrase].str
      end
      clauses.push str.join('')
      alt_clauses.push str.join('')
    end

    tree_walker = nil # must define so closure can use it below
    serialize_group = lambda do |node|
      if node.has_key? :op
        clauses.push node[:op].str
        alt_clauses.push node[:op].str
      end
      if node.has_key? :field
        clauses.push node[:field].str + ':'
        alt_clauses.push node[:field].str + ':'
      end
      clauses.push '('
      alt_clauses.push '('
      # recurse
      if node[:group].is_a?(Array)
        node[:group].each do |n|
          tree_walker.call(n)
        end
      else
        tree_walker.call( node[:group] )
      end
      clauses.push ')'
      alt_clauses.push ')'
    end

    tree_walker = lambda do |node|
      @debug and STDERR.puts "walking node: #{node.inspect}"
      if node.has_key? :group
        serialize_group.call node
      elsif node.has_key? :phrase
        serialize_phrase.call node
      elsif node.has_key? :term
        serialize_term.call node
        serialize_alt_term.call node
      else
        raise "Unknown node: #{node.inspect}"
      end

    end

    @debug and STDERR.puts "tree: #{tree.inspect}"

    if !tree.is_a?(Array)
      # single term or phrase
      tree_walker.call(tree)
    else
      tree.each do |node|
        tree_walker.call(node)
      end
    end

    # remember what was removed
    @stopped_words = stopped
    @alt_query     = alt_clauses.join(' ')

    # return new string
    clauses.join(' ')
  end

  def urlify(str)
    str.downcase.gsub(/\W/, '-').gsub(/--/, '-').gsub(/^\-|\-$/, '')
  end

  def prep_search_results

    # flag the highlighted transcript lines
    # NOTE we must use the raw internal methods so that we alter the internal structure.
    @results.response.hits.hits.each do |r|
      r._source.collection_title_url = urlify(r._source.collection_title)
      hl_lookup = {}
      excerpts  = []
      if r.try(:highlight).try(:transcript)
        r.highlight.transcript.each do |snip|
          bare_snip = snip.gsub(/<\/?em>/, '')
          hl_lookup[bare_snip] = snip
        end
      end

      # flag each transcript item that matches
      r._source.transcripts.each_with_index do |t, idx|
        if hl_lookup.has_key? t.transcript
          t.is_match = true
          t.highlight = hl_lookup[t.transcript]
          # create excerpt group
          excerpt = []
          if idx > 0 && r._source.transcripts[idx-1]["start_time"] < r._source.transcripts[idx]["start_time"]
            if r._source.transcripts[idx-1]["is_match"] == true && r._source.transcripts[idx+1]
              excerpts[excerpts.length-1].push r._source.transcripts[idx+1]
              next
            else
              excerpt.push r._source.transcripts[idx-1]
            end
          end
          excerpt.push t
          if r._source.transcripts[idx+1]
            excerpt.push r._source.transcripts[idx+1]
          end
          excerpts.push excerpt
        end
      end
 
      # tack on excerpts
      r._source.excerpts = excerpts

      # Add related if requested
      if @include_related
        related_episodes = Item.find(r._source.id).find_similar
        r._source.related = related_episodes.response.hits.hits
      end
    end
  end

  # currently a no-op placeholder
  def prep_similar_item_results
  end

  # currently a no-op placeholder
  def prep_similar_query_results
  end

  # we return one of these:
  # * autocomplete are terms strings for when there are zero hits.
  # * result suggestions are actual hits, categorized by where they matched.
  def prep_suggest_results(results)
    resp = {
      autocomplete: build_autocomplete_suggestions( results.suggest ),
    }
    if results.hits.total != 0
      resp[:hits] = build_hit_suggestions( results.hits )
    end
    resp
  end

  # returns array of strings
  def build_autocomplete_suggestions(sugg)
    acs = []
    sugg.keys.each do |ft|
      sugg[ft].each do |v|
        v.options.each do |o|
          acs.push o.text
        end
      end
    end
    acs.uniq
  end

  def build_hit_suggestions(hits)
    # determine which field matched based on 'highlight' keys,
    # and construct each rec based on that.
    recs = { tags: [], shows: [], networks: [], items: [], categories: [] }
    hits.hits.each do |hit|
      if hit.highlight
        hit.highlight.keys.each do |fn|
          if fn == 'title' || fn == 'description'
            item = hit._source
            item.idHex = item.id.to_s(16)
            recs[:items].push item
          elsif fn == 'coll_category_ci' || fn == 'coll_category'
            recs[:categories].push hit.highlight[fn]
          elsif fn == 'network'
            recs[:networks].push [ hit._source.network ] # force as array to match others
          elsif fn == 'collection_title'
            recs[:shows].push( { :title => hit.highlight[fn].first, :id => hit._source.collection_id } )
          elsif fn == 'tag'
            recs[:tags].push hit.highlight[fn]
          end
        end
      else
      # assume it is an Item
        item = hit._source
        item.idHex = item.id.to_s(16)
        recs[:items].push item
      end
    end

    # de-dupe items
    recs[:items].uniq! { |i| i.id }

    # de-dupe and de-highlight non-items
    [:categories, :networks, :tags].each do |t|
      recs[t] = recs[t].map {|v| v.first.gsub(/<\/?em>/, '')}.select {|v| v.first.length > 0 && v.first.match(/\S/) }.uniq { |v| v.downcase }
    end
    recs[:shows] = recs[:shows].uniq { |s| s[:id] }
    recs[:shows].each do |s|
      s[:title].gsub!(/<\/?em>/, '')
    end

    recs
  end
end
