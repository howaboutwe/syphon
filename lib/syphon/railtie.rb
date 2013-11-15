module Syphon
  class Railtie < Rails::Railtie
    initializer "syphon.initialize" do
      db_configs = YAML.load_file("#{Rails.root}/config/database.yml")
      db_config = db_configs["#{Rails.env}_search"] || db_configs[Rails.env]
      Syphon.database_configuration = db_config.symbolize_keys

      es_configs = YAML.load_file("#{Rails.root}/config/elasticsearch.yml")
      Syphon.configuration = es_configs[Rails.env]

      app_name = Rails.application.class.parent_name.underscore
      Syphon.index_namespace = "#{app_name}_#{Rails.env}"
    end
  end
end
