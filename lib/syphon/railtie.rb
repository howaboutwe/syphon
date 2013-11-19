require 'erb'
require 'yaml'

module Syphon
  class Railtie < Rails::Railtie
    rake_tasks do
      require 'syphon/tasks'
    end

    initializer "syphon.initialize" do
      set_database_configuration(ActiveRecord::Base.configurations, Rails.env)
      set_configuration(Rails.env, Rails.root, Rails.application.class.parent_name)
    end

    class << self
      def set_database_configuration(env, configurations)
        if Syphon.database_configuration.empty?
          config = configurations["#{env}_syphon"] || configurations[env] and
            Syphon.database_configuration = config.symbolize_keys
        end
      end

      def set_configuration(env, root, app_name)
        path = "#{root}/config/syphon.yml"
        if File.exist?(path)
          erb = File.read(path)
          yaml = ERB.new(erb).result
          if (config = YAML.load(yaml)[env])
            config.symbolize_keys!
            config[:log] = normalize_log(env, root, config[:log])
            Syphon.configuration = config
          end
        end

        if Syphon.index_namespace.nil?
          Syphon.index_namespace = "#{app_name.underscore}_#{env}"
        end
      end

      private

      def normalize_log(env, root, log)
        return nil if log == false
        log ||= "#{root}/log/syphon.#{env}.log"
        log.start_with?('/') ? log : "#{root}/#{log}"
      end
    end
  end
end
