require_relative '../test_helper'

describe Syphon::Schema do
  describe "#initialize" do
    it "configures the schema with the given block" do
      schema = Syphon::Schema.new do
        string :s, 'STRING'
      end
      schema.fields.values.map(&:name).must_equal [:s]
    end
  end

  describe "#configure" do
    describe "type methods" do
      it "builds fields with type methods" do
        schema = Syphon::Schema.new do
          string :string_field, 'STRING'
          short :short_field, 'SHORT'
          byte :byte_field, 'BYTE'
          integer :integer_field, 'INTEGER'
          long :long_field, 'LONG'
          float :float_field, 'FLOAT'
          double :double_field, 'DOUBLE'
          date :date_field, 'DATE'
          boolean :boolean_field, 'BOOLEAN'
          binary :binary_field, 'BINARY'
          geo_point :geo_point_field, 'GEO_POINT'
          nested :nested_field do
            string :string_field, 'NESTED.STRING'
          end
        end
        schema.fields.values.map(&:name).must_equal [
          :string_field, :short_field, :byte_field, :integer_field,
          :long_field, :float_field, :double_field, :date_field,
          :boolean_field, :binary_field, :geo_point_field, :nested_field,
        ]
        schema.fields.values.map(&:type).must_equal [
          :string, :short, :byte, :integer, :long, :float, :double, :date,
          :boolean, :binary, :geo_point, :nested,
        ]
        schema.fields.values.map(&:expression).must_equal [
          'STRING', 'SHORT', 'BYTE', 'INTEGER', 'LONG', 'FLOAT', 'DOUBLE',
          'DATE', 'BOOLEAN', 'BINARY', 'GEO_POINT', nil,
        ]
        nested = schema.fields[:nested_field]
        nested.nested_schema.fields.values.map(&:name).must_equal [:string_field]
        nested.nested_schema.fields.values.map(&:type).must_equal [:string]
        nested.nested_schema.fields.values.map(&:expression).must_equal ['NESTED.STRING']
      end

      it "supports dynamic expressions by passing a proc for a field expression" do
        i = nil
        schema = Syphon::Schema.new do
          string :string_field, -> { i.to_s }
        end
        i = 1
        schema.fields.values.map { |v| v.expression.call }.must_equal ['1']
        i = 2
        schema.fields.values.map { |v| v.expression.call }.must_equal ['2']
      end
    end

    describe "#from" do
      it "sets the relation" do
        schema = Syphon::Schema.new do
          from 'things'
        end
        schema.relation.must_equal 'things'
      end

      it "supports a dynamic value by passing a block" do
        i = nil
        schema = Syphon::Schema.new do
          from { i.to_s }
        end
        i = 1
        schema.relation.call.must_equal '1'
        i = 2
        schema.relation.call.must_equal '2'
      end
    end

    describe "#join" do
      it "accumulates joins" do
        schema = Syphon::Schema.new do
          from 'things'
          join 'INNER JOIN a ON 1'
          join 'INNER JOIN b ON 2'
        end
        schema.joins.must_equal ['INNER JOIN a ON 1', 'INNER JOIN b ON 2']
      end

      it "supports a dynamic value by passing a block" do
        i = j = nil
        schema = Syphon::Schema.new do
          from 'things'
          join { i.to_s }
          join { j.to_s }
        end
        i, j = 1, 2
        schema.joins.map(&:call).must_equal ['1', '2']
        i, j = 3, 4
        schema.joins.map(&:call).must_equal ['3', '4']
      end
    end

    describe "#where" do
      it "sets the conditions" do
        schema = Syphon::Schema.new do
          where 'x = 1'
        end
        schema.conditions.must_equal 'x = 1'
      end

      it "supports a dynamic value by passing a block" do
        i = nil
        schema = Syphon::Schema.new do
          where { i.to_s }
        end
        i = 1
        schema.conditions.call.must_equal '1'
        i = 2
        schema.conditions.call.must_equal '2'
      end
    end

    describe "#group_by" do
      it "sets the group clause" do
        schema = Syphon::Schema.new do
          group_by 'x, y'
        end
        schema.group_clause.must_equal 'x, y'
      end

      it "supports a dynamic value by passing a block" do
        i = nil
        schema = Syphon::Schema.new do
          group_by { i.to_s }
        end
        i = 1
        schema.group_clause.call.must_equal '1'
        i = 2
        schema.group_clause.call.must_equal '2'
      end
    end

    describe "#having" do
      it "sets the having clause" do
        schema = Syphon::Schema.new do
          having 'x = 1'
        end
        schema.having_clause.must_equal 'x = 1'
      end

      it "supports a dynamic value by passing a block" do
        i = nil
        schema = Syphon::Schema.new do
          having { i.to_s }
        end
        i = 1
        schema.having_clause.call.must_equal '1'
        i = 2
        schema.having_clause.call.must_equal '2'
      end
    end
  end

  describe "#query" do
    it "returns the complete query" do
      schema = Syphon::Schema.new do
        string :s, 'S'
        nested :inner do
          string :t, 'T'
        end
        from 'things'
        join 'INNER JOIN a ON 1'
        join 'INNER JOIN b ON 2'
        where 'a = 1'
        group_by 'x'
        having 'count(*) = 1'
      end
      schema.query.must_equal <<-EOS.strip.gsub(/\s+/, ' ')
        SELECT S AS `s`, T AS `inner[t]`
        FROM things
        INNER JOIN a ON 1
        INNER JOIN b ON 2
        WHERE a = 1
        GROUP BY x
        HAVING count(*) = 1
      EOS
    end

    it "calls blocks for dynamic queries" do
      schema = Syphon::Schema.new do
        string :s, -> { 'S' }
        nested :inner do
          string :t, -> { 'T' }
        end
        from -> { 'things' }
        join -> { 'INNER JOIN a ON 1' }
        join -> { 'INNER JOIN b ON 2' }
        where -> { 'a = 1' }
        group_by -> { 'x' }
        having -> { 'count(*) = 1' }
      end
      schema.query.must_equal <<-EOS.strip.gsub(/\s+/, ' ')
        SELECT S AS `s`, T AS `inner[t]`
        FROM things
        INNER JOIN a ON 1
        INNER JOIN b ON 2
        WHERE a = 1
        GROUP BY x
        HAVING count(*) = 1
      EOS
    end

    it "omits optional clauses when in the minimal case" do
      schema = Syphon::Schema.new do
        string :s, 'S'
        from 'things'
      end
      schema.query.must_equal "SELECT S AS `s` FROM things"
    end

    it "supports overriding the select expression" do
      schema = Syphon::Schema.new do
        string :s, 'S'
        from 'things'
      end
      schema.query(select: '1').must_equal "SELECT 1 FROM things"
    end

    it "applies the given extra scope, order, and limit" do
      schema = Syphon::Schema.new do
        string :s, 'S'
        from 'things'
        where 'a = 1'
        group_by 'x'
        having 'count(*) = 1'
      end
      options = {scope: 'b = 2', order: 'c DESC', limit: 2}
      schema.query(options).must_equal <<-EOS.strip.gsub(/\s+/, ' ')
          SELECT S AS `s`
          FROM things
          WHERE (a = 1) AND (b = 2)
          GROUP BY x
          HAVING count(*) = 1
          ORDER BY c DESC
          LIMIT 2
        EOS
    end

    it "inverts the condition if :invert is true" do
      schema = Syphon::Schema.new do
        string :s, 'S'
        from 'things'
        where 'a = 1'
      end
      schema.query(invert: true).must_equal "SELECT S AS `s` FROM things WHERE NOT (a = 1)"
    end

    it "does not invert the scope" do
      schema = Syphon::Schema.new do
        string :s, 'S'
        from 'things'
        where 'a = 1'
      end
      schema.query(invert: true, scope: 'id = 1').must_equal "SELECT S AS `s` FROM things WHERE (NOT (a = 1)) AND (id = 1)"
    end
  end

  describe "#properties" do
    it "returns the properties hash for the fields" do
      schema = Syphon::Schema.new do
        string :name, 'x'
        integer :value, 'x'
        nested :inner do
          string :s, 'x'
        end
      end

      schema.properties.must_equal({
        name: {type: :string},
        value: {type: :integer},
        inner: {
          type: :nested,
          properties: {
            s: {type: :string},
          },
        },
      })
    end
  end
end
