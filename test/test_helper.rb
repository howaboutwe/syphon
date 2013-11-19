ROOT = File.expand_path('..', File.dirname(__FILE__))

$:.unshift "#{ROOT}/lib"
require 'minitest/spec'
require 'yaml'
require 'fileutils'
require 'temporaries'
require 'debugger' if RUBY_VERSION < '2.0'
require 'looksee'
require 'rails'

require 'syphon'

config = YAML.load_file("#{ROOT}/test/config.yml").symbolize_keys
config[:database].symbolize_keys!
Syphon.configuration = config.merge(index_namespace: 'syphon')

MiniTest::Spec.class_eval do
  def self.uses_users_table
    let(:db) { Syphon.database_connection }

    before do
      columns = "id int auto_increment PRIMARY KEY, login VARCHAR(20)"
      db.query "CREATE TABLE IF NOT EXISTS users(#{columns})"
    end

    after do
      db.query "DROP TABLE IF EXISTS users"
    end
  end

  def self.uses_elasticsearch
    let(:client) { Syphon.client }

    before { clear_indices }
    after { clear_indices }
  end

  def clear_indices
    client.indices.status['indices'].keys.grep(/\Asyphon_/).
      each { |name| client.indices.delete(index: name) }
  end
end
