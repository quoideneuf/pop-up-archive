require 'elasticsearch/model'

es_url = 'http://localhost:9200'
if ENV['BONSAI_URL'] || ENV['ELASTICSEARCH_URL']
  es_url = ENV['BONSAI_URL'] || ENV['ELASTICSEARCH_URL']
end

if Rails.application.config.elasticsearch_logging || ENV['ES_DEBUG'].to_i > 0
  logger = Logger.new(STDOUT)
  logger.level =  Logger::DEBUG
  Elasticsearch::Model.client = Elasticsearch::Client.new({
    url: es_url,
    log: true,
    logger: logger,
  })
  puts "Elasticsearch logging set to DEBUG mode"
else 
  Elasticsearch::Model.client = Elasticsearch::Client.new({
    url: es_url,
  })
end

puts "Starting Elasticsearch model with server #{es_url}"
