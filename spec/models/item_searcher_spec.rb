require 'spec_helper'

describe ItemSearcher do

  before { StripeMock.start }
  after { StripeMock.stop }

  it "can parse params" do
    params = {
      q: 'foo',
      f: { :collection_id => 123 }
    }
    searcher = ItemSearcher.new(params)
    searcher.query_str.should eq params[:q]
    searcher.filters.should eq   params[:f]

  end

  it "filters out stopwords" do
    params = {
      q: 'the quick brown fox jumped over the lazy dog'
    }
    searcher = ItemSearcher.new(params)
    searcher.query_str.should eq 'quick brown fox jumped lazy dog'
  end

  it "filters stopwords from complex strings" do
    params = {
      q: %{color:brown AND size:(large or small) AND foo:"an answer"}
    }
    searcher = ItemSearcher.new(params)
    searcher.query_str.should eq %{color:brown AND size: ( large small ) AND foo:"an answer"}
    searcher.stopped_words.should eq ['or']
    searcher.alt_query.should eq %{color:brown AND size: ( large "or" small ) AND foo:"an answer"}
  end

  it "strips metacharacters from unparse-able queries" do
    params = {
      q: %{gotcha! you bad <bad> & poor (bankrupt!) string}
    }
    searcher = ItemSearcher.new(params)
    searcher.query_str.should eq %{gotcha bad bad poor bankrupt string}
    searcher.stopped_words.should eq ['you']
    searcher.alt_query.should eq %{gotcha "you" bad bad poor bankrupt string}
  end

  it "parses wildcards" do
    params = {
      q: %{foobar*},
    }
    searcher = ItemSearcher.new(params)
    searcher.query_str.should eq params[:q]
  end

  it "finds similar items" do
    # TODO why must we allow ES to sync before querying? seems like a config or env problem.
    STDERR.puts "To sleep, perchance to ... sync with ES"
    sleep 1

    # sanity check: we have N public items matching query
    Item.search('title:hooray').results.total.should eq 2
    
    #STDERR.puts '='*80
    params = {
      q: %{title:"red white and blue"},
    }
    searcher = ItemSearcher.new(params)
    results = searcher.simple_search
    #STDERR.puts results.response.inspect
    results.results.total.should eq 1
    results.results.first.title.should eq %{hooray for the red white and blue}

    #STDERR.puts '='*80
    # test single item similar match
    sim_item = results.records.first.find_similar
    sim_item.results.total.should eq 1 # only one, via tags only
    sim_item.results.first.title.should eq %{hooray for the green black and orange}

    #STDERR.puts '='*80
    # test query similar match
    sim_results = searcher.simple_similar
    #STDERR.puts sim_results.response.inspect
    sim_results.results.total.should eq 1
  end

end
