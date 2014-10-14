class Api::V1::ItemsController < Api::V1::BaseController
  expose(:collection)

  expose(:items, ancestor: :collection) do
    collection.items.includes(:collection, :hosts, :creators, :interviewers, :interviewees, :producers, :guests, :contributors, :entities, :storage_configuration).includes(audio_files:[:tasks, :transcripts], contributions:[:person])
  end

  expose(:item)
  expose(:contributions, ancestor: :item)
  expose(:users_item, ancestor: :current_users_items)

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
