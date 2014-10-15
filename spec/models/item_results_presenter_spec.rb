require 'spec_helper'

# based on elasticsearch-model/test/unit/response_base_test.rb
class MockOriginClass
  def self.index_name; 'foo'; end
  def self.document_type; 'bar'; end
end
class MockResultsClass
  include Elasticsearch::Model::Response::Base
end
def get_es_results(hitdocs=[])
  hitdocs.each do|h|
    if h.is_a?(Hash) and !h.has_key?('_source')
      h['_source'] = { id: 'es-mock-' + (1+rand(100)).to_s }
    end
  end
  search = Elasticsearch::Model::Searching::SearchRequest.new MockOriginClass, '*'
  response = Elasticsearch::Model::Response::Response.new MockOriginClass, search
  search.stub(:execute!).and_return({ 'hits' => { 'total' => 123, 'max_score' => 456, 'hits' => hitdocs } })
  return response
end
def get_es_result(hit={})
  hit[:highlight] ||= []
  return Elasticsearch::Model::Response::Result.new(hit)
end

describe ItemResultsPresenter do
  before { StripeMock.start }
  after { StripeMock.stop }

  describe "ItemResultsPresenter" do
    it 'can be created using a result object' do
      @irps = ItemResultsPresenter.new(get_es_results.response)
      @irps.should_not be_nil
    end

    it 'creates results ItemResultPresenter per row' do
      @irps = ItemResultsPresenter.new(get_es_results([{},{},{}]).response)
      @irps.results.size.should eq 3
    end

    it 'delegates respond_to?' do
      @irps = ItemResultsPresenter.new(get_es_results([{},{},{}]).response)
      @irps.should be_respond_to(:results)
      @irps.should be_respond_to(:each)
      @irps.should_not be_respond_to(:foobar)
    end

    it 'delegates method_missing' do
      result = [{},{},{}]
      @irps = ItemResultsPresenter.new(get_es_results(result).response)
      @irps.count.should eq result.count
    end
  end

  describe "ItemResultPresenter" do
    it 'can be created from a single result row' do
      @irp = ItemResultsPresenter::ItemResultPresenter.new(get_es_result)
      @irp.should_not be_loaded_from_database
    end

    it 'can be created from a single Item object' do
      @item = FactoryGirl.create :item_with_audio
      @irp = ItemResultsPresenter::ItemResultPresenter.new(get_es_result({_source: @item}))
      @irp.should_not be_loaded_from_database
      @irp.id.should eq @item.id
      @irp.database_object.should eq @item
      @irp.audio_files.count.should eq 1
    end

  end

end
