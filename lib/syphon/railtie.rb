require 'erb'
require 'yaml'

module Syphon
  class Railtie < Rails::Railtie
    this = self

    rake_tasks do
      require 'syphon/tasks'
    end

    initializer "syphon.initialize" do
      this.set_configuration(
        env: Rails.env,
        root: Rails.root,
        app_name: Rails.application.class.parent_name,
        dbconfig: ActiveRecord::Base.configurations,
      )
    end

    class << self
      def set_configuration(params = {})
        env, root, app_name, dbconfig =
          params.values_at(:env, :root, :app_name, :dbconfig)

        path = "#{root}/config/syphon.yml"
        if File.exist?(path)
          erb = File.read(path)
          yaml = ERB.new(erb).result
          config = YAML.load(yaml)[env]
        end

        config ||= {}
        config.symbolize_keys!
        config[:log] = normalize_log(env, root, config[:log])
        config[:database] ||= dbconfig[env].dup
        config[:index_namespace] ||= "#{app_name.underscore}_#{env}"
        config[:database].try(:symbolize_keys!)
        config[:elasticsearch].try(:symbolize_keys!)
        Syphon.configuration = config
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
