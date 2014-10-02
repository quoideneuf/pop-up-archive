require 'elasticsearch/model'

RESULTS_PER_PAGE = 10 unless defined?(RESULTS_PER_PAGE)

es_url = 'http://localhost:9200'
if ENV['BONSAI_URL'] || ENV['ELASTICSEARCH_URL']
  es_url = ENV['BONSAI_URL'] || ENV['ELASTICSEARCH_URL']

  # make sure we set all ENV the same, for backcompat with
  # Tire-based code.
  ENV['BONSAI_URL'] = es_url
  ENV['ELASTICSEARCH_URL'] = es_url
end

es_args = {
  url: es_url,
  transport_options: {
    timeout: 1800,
    open_timeout: 1800,
  },
  retry_on_failure: 5,
}

if ENV['ES_DEBUG'].to_i > 0
  logger = Logger.new(STDOUT)
  logger.level =  Logger::DEBUG
  es_args[:log] = true
  es_args[:logger] = logger
  puts "[#{Time.now.utc.iso8601}] Elasticsearch logging set to DEBUG mode"
end

Elasticsearch::Model.client = Elasticsearch::Client.new(es_args)

puts "[#{Time.now.utc.iso8601}] Starting Elasticsearch model with server #{es_url}"
