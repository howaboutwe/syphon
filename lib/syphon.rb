require 'active_support/inflector'
require 'elasticsearch'
require 'mysql2'

module Syphon
  autoload :Builder, 'syphon/builder'
  autoload :Index, 'syphon/index'
  autoload :Schema, 'syphon/schema'
  autoload :Source, 'syphon/source'
  autoload :VERSION, 'syphon/version'

  class << self
    attr_writer :configuration, :database_configuration, :index_namespace

    def configuration
      @configuration ||= {}
    end

    def database_configuration
      @database_configuration ||= {}
    end

    def index_namespace
      @index_namespace ||= configuration[:index_namespace]
    end

    def database_connection
      @database_connection ||= Mysql2::Client.new(database_configuration)
    end

    def client
      Thread.current[:syphon_client] ||= Elasticsearch::Client.new(elasticsearch_configuration)
    end

    def index_classes
      Syphon.configuration['index_classes'].map(&:constantize)
    end

    def elasticsearch_configuration
      configuration = Syphon.configuration.dup
      if (log = configuration[:log])
        if log.is_a?(String)
          configuration.delete(:log)
          logger = Logger.new(log)
          configuration[:logger] = logger
        end
      end
      configuration
    end
  end
end

require 'syphon/railtie' if defined?(Rails)
