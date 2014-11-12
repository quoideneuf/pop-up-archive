class Api::V1::SearchesController < Api::V1::BaseController
  def show
    query_builder = QueryBuilder.new(params, current_user)
    page = params[:page].to_i
    query_str = params[:query]
    sort_by   = params[:sort_by]

    search_query = Search.new(items_index_name) do
      if page.present? && page > 1
        from (page - 1) * RESULTS_PER_PAGE
      end
      size RESULTS_PER_PAGE

      query_builder.query do |q|
        query &q
      end

      query_builder.facets do |my_facet|
        facet my_facet.name, &my_facet
      end

      query_builder.filters do |my_filter|
        filter my_filter.type, my_filter.value
      end

      # determine sort order
      if !query_str.present? or query_str.length == 0
        sort do
          by 'created_at', 'desc'
        end
      elsif sort_by 
        sort do
          by query_builder.sort_column, query_builder.sort_order 
        end
      else
        sort do
          by 'created_at', 'desc'
          by '_score', 'desc'
        end
      end

      highlight transcript: { number_of_fragments: 0 }
    end

    response = Item.search(search_query).response
    @search = ItemResultsPresenter.new(response)
    respond_with @search
  end
end
