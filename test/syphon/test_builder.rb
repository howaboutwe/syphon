require_relative '../test_helper'

describe Syphon::Builder do
  describe "#each" do
    it "returns a document for each row with a distinct id" do
      schema = Syphon::Schema.new do
        integer :id, 0
        string :name, 'x'
      end
      results = [[1, 'one'], [2, 'two']]
      Syphon::Builder.new(results, schema).to_a.
        must_equal [{id: 1, name: 'one'}, {id: 2, name: 'two'}]
    end

    it "builds nested documents for nested fields" do
      schema = Syphon::Schema.new do
        integer :id, 0
        nested :nested1 do
          integer :a, 'x'
          integer :b, 'x'
        end
        nested :nested2 do
          integer :a, 'x'
        end
      end
      results = [[1, 10, 11, 12], [2, 20, 21, 22]]
      Syphon::Builder.new(results, schema).to_a.must_equal [
        {id: 1, nested1: {a: 10, b: 11}, nested2: {a: 12}},
        {id: 2, nested1: {a: 20, b: 21}, nested2: {a: 22}},
      ]
    end

    it "merges content from rows with the same root id" do
      schema = Syphon::Schema.new do
        integer :id, 0
        string :name, 'x'
      end
      results = [[1, 'one'], [1, 'two']]
      Syphon::Builder.new(results, schema).to_a.
        must_equal [{id: 1, name: ['one', 'two']}]
    end

    it "merges content with the same root id correctly when there are nested fields" do
      schema = Syphon::Schema.new do
        integer :id, 0
        nested :nested1 do
          integer :a, 'x'
        end
        nested :nested2 do
          integer :a, 'x'
        end
      end
      results = [[1, 10, 11], [2, 20, 21]]
      Syphon::Builder.new(results, schema).to_a.must_equal [
        {id: 1, nested1: {a: 10}, nested2: {a: 11}},
        {id: 2, nested1: {a: 20}, nested2: {a: 21}},
      ]
    end

    it "supports arrays as nested fields" do
      schema = Syphon::Schema.new do
        integer :id, 0
        nested :nested1 do
          integer :id, 0
          integer :name, 'x'
        end
      end
      results = [[1, 2, 'a'], [1, 3, 'b']]
      Syphon::Builder.new(results, schema).to_a.
        must_equal [{id: 1, nested1: [{id: 2, name: 'a'}, {id: 3, name: 'b'}]}]
    end
  end
end
