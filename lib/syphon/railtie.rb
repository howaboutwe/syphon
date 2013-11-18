module Syphon
  class Railtie < Rails::Railtie
    rake_tasks do
      require 'syphon/tasks'
    end

    initializer "syphon.initialize" do
      if Syphon.database_configuration.empty? && defined?(ActiveRecord::Base)
        db_configs = ActiveRecord::Base.configurations
        db_config = db_configs["#{Rails.env}_syphon"] || db_configs[Rails.env] and
          Syphon.database_configuration = db_config.symbolize_keys
      end

      path = "#{Rails.root}/config/syphon.yml"
      if File.exist?(path)
        erb = File.read(path)
        yaml = ERB.new(erb).result
        config = YAML.load(yaml)[Rails.env] and
          Syphon.configuration = config.symbolize_keys
      end

      if Syphon.index_namespace.nil?
        app_name = Rails.application.class.parent_name.underscore
        Syphon.index_namespace = "#{app_name}_#{Rails.env}"
      end
    end
  end
end
