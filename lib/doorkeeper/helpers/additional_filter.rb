module Doorkeeper
  module Helpers
    module AdditionalFilter

      module ClassMethods
        def doorkeeper_try(*args)
          doorkeeper_for = DoorkeeperForBuilder.create_doorkeeper_for(*args)

          before_filter doorkeeper_for.filter_options do
            valid_token(doorkeeper_for.scopes)
            return true
          end
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      private

      def valid_token(scopes)
        doorkeeper_token && doorkeeper_token.acceptable?(scopes)
      end

    end
  end
end
