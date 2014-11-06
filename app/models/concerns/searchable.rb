module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model

    # Set up callbacks for updating the index on model changes
    #
    after_commit lambda { IndexerWorker.perform_async(:index,  self.class.to_s, self.id) },
      on: :create,
      if: Proc.new { |item| item.respond_to?(:deleted_at) && item.deleted_at.blank? }

    after_commit lambda { IndexerWorker.perform_async(:update, self.class.to_s, self.id) },
      on: :update,
      if: Proc.new { |item| item.respond_to?(:deleted_at) && item.deleted_at.blank? }

    # since we do soft-deletes, we must check the deleted_at column for not null,
    # and since we want the user experience to be immediate, we do it sychronously
    # rather than firing off an IndexerWorker task.
    # NOTE this has the potential to DOS Elasticsearch server if we did lots of simultaneous soft-deletes,
    # but the most common case is a single item soft-deleted at a time.
    after_commit lambda { self.__elasticsearch__.delete_document },
      on: :destroy,
      if: Proc.new { |item| item.respond_to?(:deleted_at) && item.deleted_at.present? }
    
    after_touch  lambda { IndexerWorker.perform_async(:update, self.class.to_s, self.id) },
      if: Proc.new { |item| item.respond_to?(:deleted_at) && item.deleted_at.blank? }

    # shortcut
    def reindex
      self.__elasticsearch__.index_document
    end

    # ransack/meta_search and elasticsearch both try and inject a class search() method,
    # so we declare our own and Try To Do the Right Thing
    def self.search(*args, &block)
      if args.first.is_a?(Search)
        return self.__elasticsearch__.search(*args, &block)
      else
        return ransack(*args, &block)
      end 
    end

  end
end
