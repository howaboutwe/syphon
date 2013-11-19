module Syphon
  module Index
    def self.included(base)
      base.extend ClassMethods
      base.pre_sql ||= []
      super
    end

    module ClassMethods
      attr_accessor :pre_sql

      def inherited(subclass)
        subclass.pre_sql = pre_sql.dup
        super
      end

      def database_connection
        Syphon.database_connection
      end

      def client
        Syphon.client
      end

      def index_name
        @index_name ||=
          begin
            namespace = Syphon.index_namespace
            if namespace.to_s.empty?
              index_base_name
            else
              "#{namespace}_#{index_base_name}"
            end
          end
      end

      def index_base_name
        @index_base_name ||= name.sub(/Index\z/, '').underscore.pluralize
      end

      def sources
        @sources ||= {}
      end

      def build(options = {})
        old_internal_name = internal_index_name
        new_internal_name = new_internal_index_name(index_name)

        client.indices.create(index: new_internal_name)
        sources.each do |name, source|
          body = source.mapping
          client.indices.put_mapping(index: new_internal_name, type: source.type, body: body)
          source.import(index: new_internal_name) unless options[:schema_only]
        end

        warmups.each { |w| w.call(new_internal_name) }

        remove = {remove: {index: old_internal_name, alias: index_name}} if old_internal_name
        add = {add: {index: new_internal_name, alias: index_name}}
        client.indices.update_aliases body: {actions: [remove, add].compact}
        client.indices.delete(index: old_internal_name) if old_internal_name
      end

      def destroy
        internal_name = internal_index_name and
          client.indices.delete index: internal_name
      end

      def search(options = {})
        options[:index] ||= index_name
        options[:type] ||= source.type
        client.search(options)
      end

      def define_source(name = nil, options = {}, &block)
        source = sources[name] ||= Source.new(self, name, options)
        source.schema.configure(&block) if block
        source
      end

      def define_warmup(&block)
        warmups << block
      end

      def source(name = nil)
        sources[name]
      end

      def warmups
        @warmups ||= []
      end

      attr_writer :index_base_name

      private

      def internal_index_name
        index_name, alias_info = client.indices.get_alias(name: self.index_name).first
        index_name
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end

      def new_internal_index_name(index_name)
        i = 0
        loop do
          name = "#{index_name}_#{i}"
          return name if !client.indices.exists(index: name)
          i += 1
        end
      end
    end
  end
end
