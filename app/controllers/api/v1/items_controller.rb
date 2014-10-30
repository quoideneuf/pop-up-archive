class Api::V1::ItemsController < Api::V1::BaseController
  expose(:collection)

  expose(:collection_items) do
    if !params[:collection_id]
      raise ActiveRecord::RecordNotFound
    end
    searched_collection_items
  end

  expose(:item)
  expose(:contributions, ancestor: :item)
  expose(:users_item, ancestor: :current_users_items)

  expose(:searched_collection_items) do
    max_items = collection.items.count # TODO sane ceiling?
    query_builder = QueryBuilder.new({query:"collection_id:#{params[:collection_id].to_i}"}, current_user)
    search_query = Search.new(items_index_name) do
      query_builder.query do |q| 
        query &q
      end 
      size(max_items)
      sort do |s|
        s.by('id', 'asc')
      end
    end 
    response = Item.search(search_query).response
    ::ItemResultsPresenter.new(response).format_results
  end

  authorize_resource decent_exposure: true

  def update
    item.save
    respond_with :api, item
  end

  def show
    respond_with :api, item
  end

  def create
    item.valid?
    item.save
    respond_with :api, item
  end

  def destroy
    users_item.destroy
    respond_with :api, users_item
  end

  private

  def current_users_items
    current_user.items
  end
end
