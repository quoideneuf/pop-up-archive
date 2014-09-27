module Doorkeeper
  module OAuth
    class ClientCredentialsRequest
      class Creator
        def call(client, scopes, attributes = {}) 
          puts pp(client)
          Doorkeeper::AccessToken.create(attributes.merge({
            :application_id => client.id,
            :resource_owner_id => client.application.owner_id,  # add explicit resouce_owner_id
            :scopes         => scopes.to_s
          })) 
        end 
      end 
    end 
  end 
end
