module Syphon
  class Source
    def initialize(index, name, options = {}, &block)
      @index = index
      @name = name && name.to_sym
      @type = options[:type] || default_type
      @schema = Schema.new(&block)
    end

    attr_reader :index, :name, :type, :schema

    def mapping
      {type => {properties: schema.properties}}
    end

    def import(options = {})
      db = index.database_connection
      query = options[:query] || schema.query(order: "`#{schema.relation}`.id")
      index.pre_sql.each { |sql| db.query(sql) }
      rows = db.query(query, as: :array, stream: true, cache_rows: false)
      builder = Builder.new(rows, schema)

      builder.each_slice(1000) do |slice|
        body = []
        slice.each do |document|
          body << {index: meta(document[:id], options)} << document
        end
        client.bulk body: body
      end
      client.indices.refresh index: options[:index] || index.index_name
    end

    def update_ids(ids)
      return if ids.empty?
      query = schema.query(
        scope: "`#{schema.relation}`.id IN (#{ids.join(', ')})",
        order: "`#{schema.relation}`.id",
      )
      rows = Syphon.database_connection.query(query, as: :array)
      docs = Builder.new(rows, schema).to_a
      body = bulk_indexes(docs) + bulk_deletes(ids, docs)
      client.bulk body: body, refresh: true unless body.empty?
    end

    protected

    def client
      index.client
    end

    private

    def bulk_indexes(documents, options = {})
      documents.flat_map do |document|
        [{index: meta(document[:id], options)}, document]
      end
    end

    def bulk_deletes(ids, documents, options = {})
      ids_to_delete = ids - documents.map { |document| document[:id] }
      ids_to_delete.map do |id|
        {delete: meta(id, options)}
      end
    end

    def meta(id, options = {})
      {_index: options[:index] || index.index_name, _type: type, _id: id}
    end

    private

    def default_type
      @type_name ||= index.name.sub(/Index\z/, '').underscore.to_sym
    end
  end
end
