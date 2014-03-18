module Syphon
  class Builder
    def initialize(results, schema)
      @results = results
      @schema = schema
      @nested_docs = {}
    end

    attr_reader :results, :schema, :nested_docs

    def each
      current_id = nil
      current_document = nil
      results.each_with_index do |row, index|
        id = row[0]
        if current_id.nil? || id != current_id
          yield current_document unless current_document.nil?
          current_document = {}
          current_id = id
        end
        add_to_document(current_document, row)
      end
      yield current_document unless current_document.nil?
    end

    def add_to_document(document, row, schema = self.schema, index = 0)
      schema.fields.each do |name, field|
        if field.is_a?(Schema::NestedField)
          value = {}
          index = add_to_document(value, row, field.nested_schema, index)
        else
          value = row[index]
          index += 1
        end
        if field.multi?
          (document[field.name] ||= []) << value
        else
          document[field.name] = value
        end
      end
      index
    end

    include Enumerable

    private

    def combine(existing, incoming)
      if existing
        if existing.is_a?(Array)
          existing << incoming unless existing.include?(incoming)
        else
          existing == incoming ? existing : [existing, incoming]
        end
      else
        incoming
      end
    end
  end
end
