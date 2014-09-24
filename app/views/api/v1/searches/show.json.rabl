object nil

node(:DEBUG) { true } if @debug
node(:facets) { @search.facets }
node(:total_hits) { @search.total }
node(:max_score) { @search.max_score }
node(:page) { params[:page] }
node(:query) { params[:query] }
node(:results) { @search.format_results }

