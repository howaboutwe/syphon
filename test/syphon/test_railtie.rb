require_relative '../test_helper'

describe Syphon::Railtie do
  use_attribute_value Syphon, :configuration, {}

  describe ".set_configuration" do
    use_temporary_directory "#{ROOT}/test/tmp"

    let(:params) do
      {
        env: 'test',
        root: tmp,
        app_name: 'MyApp',
        dbconfig: {'test' => {'database' => 'ardb'}},
      }
    end

    def write_config(data)
      FileUtils.mkdir_p "#{tmp}/config"
      open("#{tmp}/config/syphon.yml", 'w') { |f| f.print data.to_yaml }
    end

    describe "when no configuration file is present" do
      it "sets all the defaults" do
        Syphon::Railtie.set_configuration(params)
        Syphon.configuration[:log].must_equal "#{tmp}/log/syphon.test.log"
        Syphon.configuration[:database].must_equal({database: 'ardb'})
        Syphon.configuration[:index_namespace].must_equal('my_app_test')
      end
    end

    describe "when a configuration file is present, but no key for the environment" do
      it "sets all the defaults" do
        write_config('other_env' => 'blah')
        Syphon::Railtie.set_configuration(params)
        Syphon.configuration[:log].must_equal "#{tmp}/log/syphon.test.log"
        Syphon.configuration[:database].must_equal({database: 'ardb'})
        Syphon.configuration[:index_namespace].must_equal('my_app_test')
      end
    end

    describe "when a valid configuration is present" do
      it "sets the configuration" do
        write_config('test' => {'reload_on_failure' => true})
        Syphon::Railtie.set_configuration(params)
        Syphon.configuration[:reload_on_failure].must_equal true
      end

      it "defaults the index namespace to one based on the app name and Rails env" do
        Syphon::Railtie.set_configuration(params)
        Syphon.index_namespace.must_equal 'my_app_test'
      end

      it "sets a custom index namespace if configured" do
        write_config('test' => {'index_namespace' => 'my_namespace'})
        Syphon::Railtie.set_configuration(params)
        Syphon.index_namespace.must_equal 'my_namespace'
      end

      it "sets a good default log path" do
        write_config('test' => {})
        Syphon::Railtie.set_configuration(params)
        Syphon.configuration[:log].must_equal "#{tmp}/log/syphon.test.log"
      end

      it "expands a given log path relative to the rails root" do
        write_config('test' => {'log' => 'path/to/my.log'})
        Syphon::Railtie.set_configuration(params)
        Syphon.configuration[:log].must_equal "#{tmp}/path/to/my.log"
      end

      it "sets no log if the log option is false" do
        write_config('test' => {'log' => false})
        Syphon::Railtie.set_configuration(params)
        Syphon.configuration[:log].must_be_nil
      end

      it "sets the given database configuration" do
        write_config('test' => {'database' => {'database' => 'mydb'}})
        Syphon::Railtie.set_configuration(params)
        Syphon.database_configuration.must_equal({database: 'mydb'})
      end

      it "defaults to a configuration for syphon in the current environment" do
        write_config('test' => {})
        params[:dbconfig] = {'test_syphon' => {database: 'syphondb'}, 'test' => {database: 'ardb'}}
        Syphon::Railtie.set_configuration(params)
        Syphon.database_configuration.must_equal({database: 'syphondb'})
      end

      it "defaults to the primary ActiveRecord configuration otherwise" do
        write_config('test' => {})
        Syphon::Railtie.set_configuration(params)
        Syphon.database_configuration.must_equal({database: 'ardb'})
      end

      it "sets the given elasticsearch configuration" do
        FileUtils.mkdir_p "#{tmp}/log"
        write_config('test' => {'elasticsearch' => {'reload_on_failure' => true}})
        Syphon::Railtie.set_configuration(params)
        Syphon.elasticsearch_configuration[:reload_on_failure].must_equal true
      end
    end
  end
end
