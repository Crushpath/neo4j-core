require 'spec_helper'

describe Neo4j::Node, "index", :type => :integration do
  before(:each) do
    Neo4j::Node.index(:name) # default :exact
    Neo4j::Node.index(:age) # default :exact
    Neo4j::Node.index(:description, :type => :fulltext)
  end

  after(:each) do
    new_tx
    Neo4j::Node.rm_field_type :exact
    Neo4j::Node.rm_field_type :fulltext
    Neo4j::Node.delete_index_type  # delete all indexes
    finish_tx
  end


  it "#asc(:field) sorts the given field as strings in ascending order " do
    new_tx
    Neo4j::Node.new :name => 'pelle@gmail.com'
    Neo4j::Node.new :name => 'gustav@gmail.com'
    Neo4j::Node.new :name => 'andreas@gmail.com'
    Neo4j::Node.new :name => 'orjan@gmail.com'

    new_tx
    result = Neo4j::Node.find('name: *@gmail.com').asc(:name)

    # then
    emails = result.collect { |x| x[:name] }
    emails.should == %w[andreas@gmail.com gustav@gmail.com orjan@gmail.com pelle@gmail.com]
  end

  it "#desc(:field) sorts the given field as strings in desc order " do
    new_tx
    Neo4j::Node.new :name => 'pelle@gmail.com'
    Neo4j::Node.new :name => 'gustav@gmail.com'
    Neo4j::Node.new :name => 'andreas@gmail.com'
    Neo4j::Node.new :name => 'zebbe@gmail.com'

    new_tx
    result = Neo4j::Node.find('name: *@gmail.com').desc(:name)

    # then
    emails = result.collect { |x| x[:name] }
    emails.should == %w[zebbe@gmail.com pelle@gmail.com gustav@gmail.com andreas@gmail.com ]
  end

  it "#asc(:field1,field2) sorts the given field as strings in ascending order " do
    new_tx
    Neo4j::Node.new :name => 'zebbe@gmail.com', :age => 3
    Neo4j::Node.new :name => 'pelle@gmail.com', :age => 2
    Neo4j::Node.new :name => 'pelle@gmail.com', :age => 4
    Neo4j::Node.new :name => 'pelle@gmail.com', :age => 1
    Neo4j::Node.new :name => 'andreas@gmail.com', :age => 5

    new_tx

    result = Neo4j::Node.find('name: *@gmail.com').asc(:name, :age)

    # then
    ages   = result.collect { |x| x[:age] }
    ages.should == [5, 1, 2, 4, 3]
  end

  it "#asc(:field1).desc(:field2) sort the given field both ascending and descending orders" do
    new_tx

    Neo4j::Node.new :name => 'zebbe@gmail.com', :age => 3
    Neo4j::Node.new :name => 'pelle@gmail.com', :age => 2
    Neo4j::Node.new :name => 'pelle@gmail.com', :age => 4
    Neo4j::Node.new :name => 'pelle@gmail.com', :age => 1
    Neo4j::Node.new :name => 'andreas@gmail.com', :age => 5

    new_tx

    result = Neo4j::Node.find('name: *@gmail.com').asc(:name).desc(:age)

    # then
    ages   = result.collect { |x| x[:age] }
    ages.should == [5, 4, 2, 1, 3]
  end

  it "can find several nodes with the same index" do
    new_tx

    thing1 = Neo4j::Node.new :name => 'thing'
    thing2 = Neo4j::Node.new :name => 'thing'
    thing3 = Neo4j::Node.new :name => 'thing'

    finish_tx

    Neo4j::Node.find("name: thing", :wrapped => true).should include(thing1)
    Neo4j::Node.find("name: thing", :wrapped => true).should include(thing2)
    Neo4j::Node.find("name: thing", :wrapped => true).should include(thing3)
  end

  it "#rm_field_type will make the index not updated when transaction finishes" do
    new_tx

    new_node = Neo4j::Node.new :name => 'andreas'
    Neo4j::Node.find("name: andreas").first.should_not == new_node

    # when
    Neo4j::Node.rm_field_type(:exact)
    finish_tx

    # then
    Neo4j::Node.find("name: andreas").first.should_not == new_node
    Neo4j::Node.index_type?(:exact).should be_false
    Neo4j::Node.index?(:name).should be_false

    # clean up
    Neo4j::Node.index(:name)
  end

  it "does not remove old index when a property is reindexed" do
    new_tx

    new_node        = Neo4j::Node.new
    new_node[:name] = 'Kalle Kula'
    new_node.add_index(:name)

    # when
    new_node[:name] = 'lala'
    new_node.add_index(:name)

    # then
    Neo4j::Node.find('name: lala').first.should == new_node
    Neo4j::Node.find('name: "Kalle Kula"').first.should == new_node
  end

  it "#rm_index removes an index" do
    new_tx

    new_node        = Neo4j::Node.new
    new_node[:name] = 'Kalle Kula'
    new_node.add_index(:name)

    # when
    new_node.rm_index(:name)

    new_node[:name] = 'lala'
    new_node.add_index(:name)

    # then
    Neo4j::Node.find('name: lala').first.should == new_node
    Neo4j::Node.find('name: "Kalle Kula"').first.should_not == new_node
  end

  it "updates an index automatically when a property changes" do
    new_tx

    new_node        = Neo4j::Node.new
    new_node[:name] = 'Kalle Kula'

    new_tx
    Neo4j::Node.find('name: "Kalle Kula"').first.should == new_node
    Neo4j::Node.find('name: lala').first.should_not == new_node

    new_node[:name] = 'lala'

    new_tx

    # then
    Neo4j::Node.find('name: lala').first.should == new_node
    Neo4j::Node.find('name: "Kalle Kula"').first.should_not == new_node
  end

  it "deleting an indexed property should not be found" do
    new_tx

    new_node        = Neo4j::Node.new :name => 'andreas'
    new_tx

    Neo4j::Node.find('name: andreas').first.should == new_node

    # when deleting an indexed property
    new_node[:name] = nil
    new_tx
    Neo4j::Node.find('name: andreas').first.should_not == new_node
  end

  it "deleting the node deletes its index" do
    new_tx

    new_node = Neo4j::Node.new :name => 'andreas'
    new_tx
    Neo4j::Node.find('name: andreas').first.should == new_node

    # when
    new_node.del
    finish_tx

    # then
    Neo4j::Node.find('name: andreas').first.should_not == new_node
  end

  it "both deleting a property and deleting the node should work" do
    new_tx

    new_node        = Neo4j::Node.new :name => 'andreas', :age => 21
    new_tx
    Neo4j::Node.find('name: andreas').first.should == new_node

    # when
    new_node[:name] = nil
    new_node[:age]  = nil
    new_node.del
    finish_tx

    # then
    Neo4j::Node.find('name: andreas').first.should_not == new_node
  end

  it "will automatically close the connection if a block was provided with the find method" do
    indexer     = Neo4j::Core::Index::Indexer.new('mocked-indexer', :node)
    index       = double('index')
    indexer.should_receive(:index_for_type).and_return(index)
    hits        = double('hits')
    index.should_receive(:query).and_return(hits)
    old_indexer = Neo4j::Node._indexer
    Neo4j::Node.instance_eval { @_indexer = indexer }
    hits.should_receive(:close)
    hits.should_receive(:first).and_return("found_node")
    found_node  = Neo4j::Node.find('name: andreas', :wrapped => false) { |h| h.first }
    found_node.should == 'found_node'

    # restore
    Neo4j::Node.instance_eval { @_indexer = old_indexer }
  end

  it "will automatically close the connection even if the block provided raises an exception" do
    indexer     = Neo4j::Core::Index::Indexer.new('mocked-indexer', :node)
    index       = double('index')
    indexer.should_receive(:index_for_type).and_return(index)
    hits        = double('hits')
    index.should_receive(:query).and_return(hits)
    old_indexer = Neo4j::Node.instance_eval { @_indexer }
    Neo4j::Node.instance_eval { @_indexer = indexer }
    hits.should_receive(:close)
    expect { Neo4j::Node.find('name: andreas', :wrapped => false) { |h| raise "oops" } }.to raise_error


    # restore
    Neo4j::Node.instance_eval { @_indexer = old_indexer }
  end

  describe "add_index" do
    it "should create index on a node" do
      new_tx

      new_node        = Neo4j::Node.new
      new_node[:name] = 'andreas'

      # when
      new_node.add_index(:name)

      # then
      Neo4j::Node.find("name: andreas", :wrapped => false).get_single.should == new_node
    end


    it "should create index on a node with a given type (e.g. fulltext)" do
      new_tx

      new_node               = Neo4j::Node.new
      new_node[:description] = 'hej'

      # when
      new_node.add_index(:description)

      # then
      Neo4j::Node.find('description: "hej"', :type => :fulltext, :wrapped => false).get_single.should == new_node
      #Neo4j::Node.find('name: "hej"').get_single.should == new_node
    end

  end
end
