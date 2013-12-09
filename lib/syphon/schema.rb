module Syphon
  class Schema
    def initialize(&block)
      @fields = {}
      @relation = nil
      @joins = []
      @conditions = nil
      @group_clause = nil
      @having_clause = nil
      configure(&block) if block
    end

    attr_reader :fields, :joins
    attr_accessor :relation, :conditions, :group_clause, :having_clause

    def configure(&block)
      DSL.new(self)._eval(&block)
    end

    def query(options = {})
      order = options[:order] and
        order_by_fragment = "ORDER BY #{query_fragment(order)}"
      limit = options[:limit] and
        limit_fragment = "LIMIT #{query_fragment(limit)}"

      select_fragment = options[:select] || select_fragments
      where_fragment = where_fragment(options.slice(:scope, :invert))

      <<-EOS.strip.gsub(/\s+/, ' ')
        SELECT #{select_fragment}
        FROM #{query_fragment(relation)}
        #{joins_fragment}
        #{where_fragment}
        #{group_by_fragment}
        #{having_fragment}
        #{order_by_fragment}
        #{limit_fragment}
      EOS
    end

    def properties
      mapping = {}
      fields.each do |name, field|
        mapping[name] = field.properties
      end
      mapping
    end

    private

    def select_fragments
      fields.map { |name, field| field.select }.join(', ')
    end

    def joins_fragment
      return nil if joins.empty?
      joins.map { |j| query_fragment(j) }.join(' ')
    end

    def where_fragment(options)
      fragment = query_fragment(conditions) || '1'
      fragment = "NOT (#{fragment})" if options[:invert]
      scope = options[:scope] and
        fragment = "(#{fragment}) AND (#{scope})"
      fragment == '1' ? nil : "WHERE #{fragment}"
    end

    def group_by_fragment
      clause = query_fragment(group_clause) and
        "GROUP BY #{clause}"
    end

    def having_fragment
      clause = query_fragment(having_clause) and
        "HAVING #{clause}"
    end

    def query_fragment(string_or_callable)
      if string_or_callable.respond_to?(:call)
        string_or_callable.call
      elsif string_or_callable
        string_or_callable
      end
    end

    class Field
      def initialize(schema, name, type, expression, options = {})
        @schema = schema
        @name = name.to_sym
        @type = type
        @expression = expression
        @properties = options.merge(type: type)
      end

      attr_reader :schema, :name, :type, :expression, :properties

      def select(outer = nil)
        name = outer ? "#{outer}[#{self.name}]" : self.name
        "#{schema.send(:query_fragment, expression)} AS `#{name}`"
      end
    end

    class NestedField < Field
      def initialize(schema, name, options = {}, &block)
        super(schema, name, :nested, nil, options)
        @nested_schema = Schema.new(&block)
      end

      attr_reader :nested_schema

      def properties
        super.merge(properties: nested_schema.properties)
      end

      def select
        nested_schema.fields.map { |n, f| f.select(name) }.join(', ')
      end
    end

    DSL = Struct.new(:schema) do
      def _eval(&block)
        if block.arity == 1
          block.call(self)
        else
          instance_eval(&block)
        end
        schema
      end

      def field(name, type, expression, options = {})
        schema.fields[name.to_sym] = Field.new(schema, name, type, expression, options)
      end

      %w[string short byte integer long float double date boolean binary geo_point].each do |type|
        class_eval <<-EOS, __FILE__, __LINE__ + 1
          def #{type}(name, expression, options = {})
            field(name, :#{type}, expression, options)
          end
        EOS
      end

      def nested(name, options = {}, &block)
        schema.fields[name.to_sym] = NestedField.new(schema, name, options, &block)
      end

      {
        from: :relation,
        where: :conditions,
        group_by: :group_clause,
        having: :having_clause,
      }.each do |dsl_method, schema_attribute|
        class_eval <<-EOS, __FILE__, __LINE__ + 1
          def #{dsl_method}(string = nil, &block)
            string && block and
              raise ArgumentError, "both string and block given"
            schema.#{schema_attribute} = string || block
          end
        EOS
      end

      def join(string = nil, &block)
        string && block and
          raise ArgumentError, "both string and block given"
        schema.joins << (string || block)
      end
    end
  end
end
