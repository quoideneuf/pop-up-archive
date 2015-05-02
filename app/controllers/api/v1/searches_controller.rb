class Api::V1::SearchesController < Api::V1::BaseController
  
  def show
    prep_search or return

    # try try try to get some results. If none for AND search, expand to OR.
    if @es_resp.response.hits.total == 0
      Rails.logger.debug "zero hits for initial query. trying again with looser logical OR"
      params[:op] = 'OR'
      prep_search or return
    end 
    @search = ItemResultsPresenter.new(@es_resp.response)
    respond_with @search 
  end

  def prep_search
    query_str = params[:q] || params[:query]

    # if no query defined, respond with error code 400
    if (!query_str or !query_str.match(/\S/))
      #render :json => {:error => "Empty search query", :status => 400}.to_json, :status => 400 and return
    end 

    @searcher = ItemSearcher.new(params)
    @es_resp = @searcher.search
    @query  = query_str  # what the user entered, not necessarily what was searched for.
    @query
  end
 
end
