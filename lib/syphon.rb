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
    attr_writer :configuration

    def configuration
      @configuration ||= {}
    end

    def database_configuration
      configuration[:database] || {}
    end

    def elasticsearch_configuration
      configuration = Syphon.configuration[:elasticsearch].try(:dup) || {}
      configuration[:logger] = logger
      configuration
    end

    def index_namespace
      configuration[:index_namespace]
    end

    def database_connection
      Thread.current[:syphon_database_connection] ||= Mysql2::Client.new(database_configuration)
    end

    def client
      Thread.current[:syphon_client] ||= Elasticsearch::Client.new(elasticsearch_configuration)
    end

    def index_classes
      Syphon.configuration['index_classes'].map(&:constantize)
    end

    def logger
      Thread.current[:syphon_logger] ||= make_logger
    end

    def logger=(logger)
      Thread.current[:syphon_logger] = logger
    end

    private

    def make_logger
      log = Syphon.configuration[:log] || STDOUT
      Logger.new(log).tap do |logger|
        logger.formatter = lambda do |level, time, progname, message|
          "#{time.strftime('%Y-%m-%d: %H:%M:%S')}: #{level}: #{message}\n"
        end
        level = configuration[:log_level] and
          logger.level = Logger.const_get(level.upcase)
      end
    end
  end
end

require 'syphon/railtie' if defined?(Rails)
