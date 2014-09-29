require 'elasticsearch/model'

es_url = 'http://localhost:9200'
if ENV['BONSAI_URL'] || ENV['ELASTICSEARCH_URL']
  es_url = ENV['BONSAI_URL'] || ENV['ELASTICSEARCH_URL']
end
Elasticsearch::Model.client = Elasticsearch::Client.new({
  url: es_url,
  log: true,
  trace: true
})

if Rails.application.config.elasticsearch_logging || ENV['DEBUG']
  logger = Logger.new(STDOUT)
  logger.level =  Logger::DEBUG
  Elasticsearch::Model.client.transport.logger = logger
end

puts "Starting Elasticsearch model with server #{es_url}"
