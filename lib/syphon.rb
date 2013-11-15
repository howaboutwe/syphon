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
    attr_accessor :configuration, :database_configuration, :index_namespace

    def database_connection
      @database_connection ||= Mysql2::Client.new(database_configuration)
    end

    def client
      Thread.current[:syphon_client] ||= Elasticsearch::Client.new(Syphon.configuration)
    end

    def classes
      Syphon.configuration['indices'].map(&:constantize)
    end
  end
end

require 'syphon/railtie' if defined?(Rails)
