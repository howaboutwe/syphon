require_relative '../test_helper'

describe Syphon::Source do
  before do
    Object.const_set(:TestIndex, Class.new)
    TestIndex.send :include, Syphon::Index
  end

  after do
    Object.send(:remove_const, :TestIndex)
  end

  let(:source) { TestIndex.source }

  describe "#initialize" do
    it "sets a default type" do
      source = Syphon::Source.new(TestIndex, :things_source)
      source.name.must_equal :things_source
      source.type.must_equal :test
    end

    it "sets the name and type" do
      source = Syphon::Source.new(TestIndex, :things_source, type: :custom_type)
      source.name.must_equal :things_source
      source.type.must_equal :custom_type
    end

    it "initializes the schema from the given block" do
      source = Syphon::Source.new(TestIndex, :things_source) do
        string :name, 'x'
      end
      source.schema.fields.keys.must_equal [:name]
    end
  end

  describe "#mapping" do
    it "returns the ElasticSearch mapping" do
      source = Syphon::Source.new(TestIndex, :things_source, type: :thing) do
        string :name, 'x'
      end

      source.mapping.must_equal({
        thing: {
          properties: {
            name: {
              type: :string
            },
          },
        },
      })
    end
  end

  describe "#import" do
    uses_users_table
    uses_elasticsearch

    before do
      TestIndex.class_eval do
        define_source do
          integer :id, 'id'
          string :login, 'login', stored: true
          from 'users'
        end
      end
      TestIndex.build(schema_only: true)
    end

    it "imports the data as configured by the SQL query" do
      db.query "INSERT INTO users(login) VALUES('alice')"
      source.import

      hits = client.search(index: TestIndex.index_name)['hits']['hits']
      hits.map { |doc| doc['_source']['login'] }.must_equal ['alice']
    end

    it "imports data correctly the second time" do
      db.query "INSERT INTO users(login) VALUES('alice')"
      source.import

      db.query "INSERT INTO users(login) VALUES('bob')"
      source.import

      hits = client.search(index: TestIndex.index_name)['hits']['hits']
      hits.map { |doc| doc['_source']['login'] }.sort.must_equal ['alice', 'bob']
    end

    it "uses the given index name" do
      client.indices.create(index: 'syphon_custom')
      db.query "INSERT INTO users(login) VALUES('alice')"
      source.import(index: 'syphon_custom')

      hits = client.search(index: 'syphon_custom')['hits']['hits']
      hits.map { |doc| doc['_source']['login'] }.must_equal ['alice']
    end
  end

  describe "#update" do
    uses_users_table
    uses_elasticsearch

    before do
      TestIndex.class_eval do
        define_source do
          integer :id, 'id'
          string :login, 'login', stored: true
          from 'users'
        end
      end
      TestIndex.build(schema_only: true)
    end

    it "updates the index from the database, scoping with the given conditions" do
      db.query "INSERT INTO users(login) VALUES('alice'), ('bob')"
      TestIndex.build

      hits = client.search(index: TestIndex.index_name)['hits']['hits']
      hits.map { |doc| doc['_source']['login'] }.sort.must_equal ['alice', 'bob']

      db.query "UPDATE users SET login = 'superalice' WHERE login = 'alice'"
      db.query "UPDATE users SET login = 'wonderbob' WHERE login = 'bob'"
      bob_id = db.query("SELECT id FROM users WHERE login = 'wonderbob'", as: :array).to_a[0][0]
      source.update_ids([bob_id])

      hits = client.search(index: TestIndex.index_name)['hits']['hits']
      hits.map { |doc| doc['_source']['login'] }.sort.must_equal ['alice', 'wonderbob']
    end

    it "deletes records that should no longer exist" do
      db.query "INSERT INTO users(login) VALUES('alice'), ('bob')"
      TestIndex.build

      bob_id = db.query("SELECT id FROM users WHERE login = 'bob'", as: :array).to_a[0][0]
      db.query "DELETE FROM users WHERE id = #{bob_id}"
      source.update_ids([bob_id])

      hits = client.search(index: TestIndex.index_name)['hits']['hits']
      hits.map { |doc| doc['_source']['login'] }.must_equal ['alice']
    end
  end
end
