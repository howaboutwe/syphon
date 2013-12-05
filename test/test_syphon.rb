require_relative 'test_helper'

describe Syphon do
  describe ".configuration" do
    use_attribute_value Syphon, :configuration, nil

    it "defaults to an empty hash" do
      Syphon.configuration.must_equal({})
    end
  end

  describe ".database_configuration" do
    use_instance_variable_value Syphon, :configuration, nil

    it "defaults to an empty hash" do
      Syphon.database_configuration.must_equal({})
    end
  end

  describe ".index_namespace" do
    describe "when a namespace is configured" do
      use_instance_variable_value Syphon, :configuration, {index_namespace: 'NAMESPACE'}

      it "is the configured index namespace" do
        Syphon.index_namespace.must_equal('NAMESPACE')
      end
    end

    describe "when no namespace is configured" do
      use_instance_variable_value Syphon, :configuration, {}

      it "is nil" do
        Syphon.index_namespace.must_be_nil
      end
    end
  end

  describe ".database_configuration" do
    use_attribute_value Syphon, :configuration, nil

    it "uses the configured database configuration" do
      Syphon.configuration = {database: {database: 'mydb'}}
      Syphon.database_configuration.must_equal({database: 'mydb'})
    end
  end

  describe ".elasticsearch_configuration" do
    use_attribute_value Syphon, :configuration, nil
    use_attribute_value Syphon, :logger, nil
    use_temporary_directory "#{ROOT}/test/tmp"

    it "includes all configured elasticserach settings" do
      Syphon.configuration = {elasticsearch: {reload_on_failure: true}}
      Syphon.elasticsearch_configuration[:reload_on_failure].must_equal true
    end

    it "adds the Syphon logger" do
      logger = Logger.new(logger)
      Syphon.logger = logger
      Syphon.elasticsearch_configuration[:logger].must_equal logger
    end
  end

  describe ".logger" do
    use_attribute_value Syphon, :configuration, nil
    use_attribute_value Syphon, :logger, nil
    use_temporary_directory "#{ROOT}/test/tmp"

    it "uses the configured log path and log level" do
      Syphon.configuration[:log] = "#{tmp}/syphon.log"
      Syphon.configuration[:log_level] = 'info'
      Syphon.logger.debug 'DEBUG LEVEL'
      Syphon.logger.info 'INFO LEVEL'
      File.read("#{ROOT}/test/tmp/syphon.log").wont_include 'DEBUG LEVEL'
      File.read("#{ROOT}/test/tmp/syphon.log").must_include 'INFO LEVEL'
    end
  end
end
