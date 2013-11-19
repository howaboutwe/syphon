require_relative '../test_helper'

describe Syphon::Railtie do
  before do
    Syphon.database_configuration = {}
    Syphon.configuration = {}
    Syphon.index_namespace = nil
  end

  describe ".set_database_configuration" do
    describe "when no database configuration has been set" do
      it "prefers a syphon-specific configuration if available" do
        configurations = {
          'test' => {'database' => 'standard'},
          'test_syphon' => {'database' => 'syphonic'},
        }
        Syphon::Railtie.set_database_configuration('test', configurations)
        Syphon.database_configuration.must_equal({database: 'syphonic'})
      end

      it "otherwise uses the standard ActiveRecord one if available" do
        configurations = {'test' => {'database' => 'standard'}}
        Syphon::Railtie.set_database_configuration('test', configurations)
        Syphon.database_configuration.must_equal({database: 'standard'})
      end
    end

    describe "when a database configuration has already been set" do
      before { Syphon.database_configuration = {database: 'custom'} }

      it "leaves it alone" do
        configurations = {'test' => {'database' => 'standard'}}
        Syphon::Railtie.set_database_configuration('test', configurations)
        Syphon.database_configuration.must_equal({database: 'custom'})
      end
    end
  end

  describe ".set_configuration" do
    use_temporary_directory "#{ROOT}/test/tmp"

    def write_config(data)
      FileUtils.mkdir_p "#{tmp}/config"
      open("#{tmp}/config/syphon.yml", 'w') { |f| f.print data.to_yaml }
    end

    describe "when no configuration file is present" do
      it "does not cry" do
        Syphon::Railtie.set_configuration('test', tmp, 'MyApp')
        Syphon.configuration.must_equal({})
      end
    end

    describe "when a configuration file is present, but no key for the environment" do
      it "does not cry" do
        write_config('other_env' => 'blah')
        Syphon::Railtie.set_configuration('test', tmp, 'MyApp')
        Syphon.configuration.must_equal({})
      end
    end

    describe "when a valid configuration is present" do
      it "sets the configuration" do
        write_config('test' => {'reload_on_failure' => true})
        Syphon::Railtie.set_configuration('test', tmp, 'MyApp')
        Syphon.configuration[:reload_on_failure].must_equal true
      end

      it "defaults the index namespace to one based on the app name and Rails env" do
        Syphon::Railtie.set_configuration('test', tmp, 'MyApp')
        Syphon.index_namespace.must_equal 'my_app_test'
      end

      it "sets a custom index namespace if configured" do
        write_config('test' => {'index_namespace' => 'my_namespace'})
        Syphon::Railtie.set_configuration('test', tmp, 'MyApp')
        Syphon.index_namespace.must_equal 'my_namespace'
      end

      it "sets a good default log path" do
        write_config('test' => {})
        Syphon::Railtie.set_configuration('test', tmp, 'MyApp')
        Syphon.configuration[:log].must_equal "#{tmp}/log/syphon.test.log"
      end

      it "expands a given log path relative to the rails root" do
        write_config('test' => {'log' => 'path/to/my.log'})
        Syphon::Railtie.set_configuration('test', tmp, 'MyApp')
        Syphon.configuration[:log].must_equal "#{tmp}/path/to/my.log"
      end

      it "sets no log if the log option is false" do
        write_config('test' => {'log' => false})
        Syphon::Railtie.set_configuration('test', tmp, 'MyApp')
        Syphon.configuration[:log].must_be_nil
      end
    end
  end
end
