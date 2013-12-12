require_relative '../test_helper'

describe Syphon::Index do
  before do
    Object.const_set(:TestIndex, Class.new)
    TestIndex.send :include, Syphon::Index
  end

  after do
    Object.send(:remove_const, :TestIndex)
  end

  describe ".index_name" do
    describe "when no index namespace is set" do
      use_attribute_value Syphon, :configuration, {index_namespace: nil}

      it "it is the index base name" do
        TestIndex.index_name.must_equal 'tests'
      end
    end

    describe "when the index namespace is empty" do
      use_attribute_value Syphon, :configuration, {index_namespace: ''}

      it "it is treated the same as nil" do
        TestIndex.index_name.must_equal 'tests'
      end
    end

    describe "when an index namespace is set" do
      it "prefixes with the namespace and an underscore" do
        TestIndex.index_name.must_equal 'syphon_tests'
      end
    end
  end

  describe ".index_base_name" do
    it "is based on the class name" do
      TestIndex.index_base_name.must_equal 'tests'
    end

    it "can be overridden" do
      TestIndex.index_base_name = 'wibble'
      TestIndex.index_base_name.must_equal 'wibble'
    end

    it "contributes to the index name" do
      TestIndex.index_base_name = 'wibble'
      TestIndex.index_name.must_equal 'syphon_wibble'
    end
  end

  describe ".define_source" do
    it "defaults the name and type" do
      TestIndex.class_eval do
        define_source
      end

      source = TestIndex.source
      source.name.must_be_nil
      source.type.must_equal :test
    end

    it "defines a source with the given name and fields" do
      TestIndex.class_eval do
        define_source :custom_name, type: :thing do
          string :value, 'x'
        end
      end

      source = TestIndex.source(:custom_name)
      source.name.must_equal :custom_name
      source.type.must_equal :thing
      source.schema.fields.keys.must_equal [:value]
    end
  end

  describe ".build" do
    uses_users_table
    uses_elasticsearch

    before do
      clear_indices

      TestIndex.class_eval do
        define_source do
          string :login, "users.login"
          from 'users'
        end
      end
    end

    it "builds the index (as an alias of an underlying index) if it does not yet exist" do
      db.query "INSERT INTO users(login) VALUES('alice')"
      TestIndex.build

      hits = TestIndex.search['hits']['hits']
      hits.map { |doc| doc['_source']['login'] }.must_equal ['alice']

      db.query "DELETE FROM users"
      db.query "INSERT INTO users(login) VALUES('bob')"

      TestIndex.build

      hits = TestIndex.search['hits']['hits']
      hits.map { |doc| doc['_source']['login'] }.must_equal ['bob']
    end

    it "passes configured index settings" do
      TestIndex.index_settings = {number_of_shards: 23}
      TestIndex.build
      index = TestIndex.client.indices.get_alias(name: TestIndex.index_name).keys.first
      num_shards = client.indices.get_settings[index]['settings']['index.number_of_shards']
      num_shards.must_equal '23'
    end

    it "runs all warmups between building the new index and rotating it in" do
      this = self
      runs = []
      TestIndex.class_eval do
        define_warmup do |new_index|
          client.indices.exists(index: new_index)
          -> { client.indices.get_alias(name: TestIndex.index_name) }.
            must_raise(Elasticsearch::Transport::Transport::Errors::NotFound)
          runs << 1
        end

        define_warmup do |new_index|
          runs << 2
        end
      end

      TestIndex.build
      runs.must_equal [1, 2]
    end
  end

  describe ".destroy" do
    uses_users_table
    uses_elasticsearch

    before do
      TestIndex.class_eval do
        define_source do
          string :login, "users.login"
          from 'users'
        end
      end
      TestIndex.build
    end

    it "deletes the index and any aliases to it" do
      client.indices.exists(index: TestIndex.index_name).must_equal true
      client.indices.get_alias(name: TestIndex.index_name).size.must_equal 1

      TestIndex.destroy

      -> { client.indices.get_alias(name: TestIndex.index_name) }.
        must_raise(Elasticsearch::Transport::Transport::Errors::NotFound)
      client.indices.exists(index: TestIndex.index_name).must_equal false
    end
  end
end
