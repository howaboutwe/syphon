require_relative 'test_helper'

describe Syphon do
  describe ".configuration" do
    use_attribute_value Syphon, :configuration, nil

    it "defaults to an empty hash" do
      Syphon.configuration.must_equal({})
    end
  end

  describe ".database_configuration" do
    use_instance_variable_value Syphon, :database_configuration, nil

    it "defaults to an empty hash" do
      Syphon.database_configuration.must_equal({})
    end
  end

  describe ".index_namespace" do
    use_instance_variable_value Syphon, :index_namespace, nil
    use_instance_variable_value Syphon, :configuration, {index_namespace: 'NAMESPACE'}

    it "defaults to the configured index namespace" do
      Syphon.index_namespace.must_equal('NAMESPACE')
    end
  end

  describe ".elasticsearch_configuration" do
    use_attribute_value Syphon, :configuration, nil
    use_temporary_directory "#{ROOT}/test/tmp"

    it "is creates a logger if a log path is given" do
      Syphon.configuration[:log] = "#{tmp}/syphon.log"
      Syphon.elasticsearch_configuration[:logger].info 'FINDME'
      File.read("#{ROOT}/test/tmp/syphon.log").must_include 'FINDME'
    end
  end
end
