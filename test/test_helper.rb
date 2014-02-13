ROOT = File.expand_path('..', File.dirname(__FILE__))

$:.unshift "#{ROOT}/lib"
require 'minitest/spec'
require 'yaml'
require 'fileutils'
require 'temporaries'
require 'byebug'
require 'looksee'
require 'rails'

require 'syphon'

config = YAML.load_file("#{ROOT}/test/config.yml").symbolize_keys
config[:database].symbolize_keys!
Syphon.configuration = config.merge(index_namespace: 'syphon')
Syphon.logger = Logger.new('/dev/null')

MiniTest::Spec.class_eval do
  def self.uses_users_table
    let(:db) { Syphon.database_connection }

    include Module.new {
      extend MiniTest::Spec::DSL

      before do
        columns = "id int auto_increment PRIMARY KEY, login VARCHAR(20)"
        db.query "CREATE TABLE IF NOT EXISTS users(#{columns})"
      end

      after do
        db.query "DROP TABLE IF EXISTS users"
      end
    }
  end

  def self.uses_elasticsearch
    let(:client) { Syphon.client }

    include Module.new {
      extend MiniTest::Spec::DSL

      before { clear_indices }
      after { clear_indices }
    }
  end

  def clear_indices
    client.indices.status['indices'].keys.grep(/\Asyphon_/).
      each { |name| client.indices.delete(index: name) }
  end
end
