source 'https://rubygems.org'

ruby '2.0.0'

gem 'rails', '~> 3.2.17'

# Rails 4 pre-prep
gem 'strong_parameters'
gem 'routing_concerns'
gem 'etagger', github: 'rails/etagger'
gem 'cache_digests'
gem 'dalli'

gem 'media_monster_client'
gem 'pg'
# gem 'activerecord-postgres-hstore', github: 'engageis/activerecord-postgres-hstore'
gem 'activerecord-postgres-hstore', '~> 0.6.0'
gem 'postgres_ext'
gem 'acts_as_list'
gem 'multi_json', '~> 1.5.0'

gem 'decent_exposure', '~> 2.1.0'
# gem 'decent_exposure', github: 'voxdolo/decent_exposure'

# login to prx.org using omniauth
gem 'omniauth'
gem 'omniauth-oauth2', '~> 1.1.0'
gem 'omniauth-prx', github: 'PRX/omniauth-prx'
gem 'omniauth-twitter'
gem 'omniauth-facebook'
gem 'devise', '~> 3.2'
gem 'devise_invitable', github: 'scambra/devise_invitable'
gem 'switch_user'
gem 'bootstrap_form'
gem 'cancan'

# require a new enough rest-client on behalf of other gems that use it
# NOTE that v 1.7.2 has a security bug but it is the newest version as of 2015-01-27
gem 'rest-client', '~> 1.7.2'

# search with elasticsearch
gem 'elasticsearch-model', '~> 0.1.6'
gem 'elasticsearch-rails', '~> 0.1.6'

# server-side templates
gem 'slim-rails', '~> 1.0'
gem 'rabl'

# background processing
gem 'sidekiq'

# misc
gem 'copyrighter'
gem 'geocoder'
gem 'will_paginate'

gem 'carrierwave'

gem 'rmagick'
gem 'mini_magick', :git => 'git://github.com/fschwahn/mini_magick.git'
gem 'fog', '~> 1.11.1'

gem 'heroku-api', '~> 0.3.10'
gem 'excon', '~> 0.21.0'

gem 'pb_core', '~> 0.1.6'
# gem 'pb_core', path: '~/dev/projects/pb_core'

gem 'chronic'

gem 'state_machine'

gem 'doorkeeper', "~> 1.4.1"

gem "acts_as_paranoid", "~> 0.4.2"

gem 'newrelic_rpm'

gem 'feedzirra', github: 'pauldix/feedzirra'

gem 'rolify', "~> 3.4.1"

gem 'sanitize'

gem 'soundcloud'

gem 'amara', "~> 0.1.1"

gem 'speechmatics', github: 'popuparchive/speechmatics'

gem 'prerender_rails'

# gem 'amara', :path => '../amara'
# gem 'amara', github: 'PRX/amara'

gem 'countries'
gem 'language_list'

gem 'stripe'

gem 'redis-namespace', '>= 1.3.1'
gem 'redis-rails'

gem 'jplayer-rails'

gem 'gibbon'

gem 'rack-cors'

gem 'dbpedia'

gem 'text-table'

gem 'mixpanel-ruby'

gem 'activeadmin', github: 'activeadmin', branch: 'master'
gem 'active_admin_sidebar'
gem 'coffee-script'
gem 'ansi'

group :assets do
  gem 'sprockets'
  gem 'sass-rails', '~> 3.2'
  gem 'uglifier', '>= 1.0.3'
  gem 'bootstrap-sass'
  gem 'angularjs-rails-resource'
  gem 'font-awesome-sass-rails', github: 'iterion/font-awesome-sass-rails'
  gem 'ng_player_hater-rails', '~> 0.0.4'
end

group :development do
  gem 'quiet_assets'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'ruby_gntp'
  gem 'guard-rspec'
  gem 'guard-jasmine'
  gem "guard-bundler", ">= 1.0.0"
  gem 'spring'
  gem 'pry-rails'
  gem 'pry-stack_explorer'
  gem 'pry-debugger'
  gem 'pry-remote'
 end

group :development, :test do
  gem 'rspec-rails', '~> 2.4'
  gem 'rspec-mocks'
  gem 'database_cleaner'
  gem 'listen'
  gem 'terminal-notifier-guard'
  gem 'growl', require: false
  gem 'rb-inotify', require: false
  gem 'rb-fsevent', require: false
  gem 'rb-fchange', require: false

  # Test JS using Jasmine
  gem 'jasmine'
  gem 'jasmine-rails'
    
end

group :test do
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'poltergeist'
  gem 'shoulda-matchers'
  gem 'stripe-ruby-mock', require: 'stripe_mock'
  gem 'simplecov'
  gem 'coveralls'
  gem 'elasticsearch-extensions'
end

group :development, :production, :staging do
  gem 'sinatra' # for sidekiq
  gem 'autoscaler', '~> 0.2.0'
  gem 'foreman'
  gem 'unicorn'
end

group :production, :staging do
  gem 'rails_12factor'
end
