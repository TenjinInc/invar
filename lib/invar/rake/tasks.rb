# frozen_string_literal: true

require 'invar'

require 'rake'
require 'tempfile'

require_relative 'task/config'
require_relative 'task/secrets'
require_relative 'task/status'

module Invar
   # Rake task module for Invar-related tasks.
   #
   # The specific rake task implementations are delegated to handlers in Invar::Rake::Task
   #
   # @see Invar::Rake::Tasks.define
   module Rake
      # RakeTask builder class. Use Tasks.define to generate the needed tasks.
      class Tasks
         include ::Rake::Cloneable
         include ::Rake::DSL

         # Shorthand for Invar::Rake::Tasks.new.define
         #
         # @param (see #define)
         # @see Tasks#define
         def self.define(...)
            new.define(...)
         end

         # Defines helpful Rake tasks for the given namespace.
         #
         # @param namespace [String] The namespace to search for files within
         def define(namespace: nil)
            raise ArgumentError, ':namespace keyword argument cannot be nil' if namespace.nil?
            raise ArgumentError, ':namespace keyword argument cannot be empty string' if namespace.empty?

            define_all_tasks(namespace)
         end

         private

         def define_all_tasks(app_namespace)
            namespace :invar do
               define_init_task(app_namespace)

               define_config_task(app_namespace)
               define_secrets_tasks(app_namespace)

               define_info_tasks(app_namespace)
            end
         end

         def define_init_task(app_namespace)
            desc 'Create new configuration and encrypted secrets files'
            task :init, [:mode] do |_task, args|
               mode = args.mode

               config  = ::Invar::Rake::Task::ConfigFileHandler.new(app_namespace)
               secrets = ::Invar::Rake::Task::SecretsFileHandler.new(app_namespace)

               case mode
               when 'config'
                  secrets = nil
               when 'secrets'
                  config = nil
               else
                  raise ArgumentError, "unknown mode '#{ mode }'. Must be one of 'config' or 'secrets'" unless mode.nil?
               end

               assert_init_conditions(config&.file_path, secrets&.file_path)

               config&.create
               secrets&.create
            end
         end

         def define_config_task(app_namespace)
            desc 'Edit the config in your default editor'
            task :configs do
               ::Invar::Rake::Task::ConfigFileHandler.new(app_namespace).edit
            end

            # alias
            task config: ['configs']
         end

         def define_secrets_tasks(app_namespace)
            desc 'Edit the encrypted secrets file in your default editor'
            task :secrets do
               ::Invar::Rake::Task::SecretsFileHandler.new(app_namespace).edit
            end

            # alias
            task secret: ['secrets']

            desc 'Encrypt the secrets file with a new generated key'
            task :rotate do
               ::Invar::Rake::Task::SecretsFileHandler.new(app_namespace).rotate
            end
         end

         def define_info_tasks(app_namespace)
            desc 'Show directories to be searched for the given namespace'
            task :paths do
               ::Invar::Rake::Task::StatusHandler.new(app_namespace).show_paths
            end
         end

         def assert_init_conditions(config_file, secrets_file)
            return unless config_file&.exist? || secrets_file&.exist?

            msg = if !config_file.exist?
                     <<~MSG
                        Abort: Secrets file already exists (#{ secrets_file })
                        Run this to init only the config file: bundle exec rake tasks invar:init[config]
                     MSG
                  elsif !secrets_file.exist?
                     <<~MSG
                        Abort: Config file already exists (#{ config_file })
                        Run this to init only the secrets file: bundle exec rake tasks invar:init[secrets]
                     MSG
                  else
                     <<~MSG
                        Abort: Files already exist (#{ config_file }, #{ secrets_file })
                        Maybe you meant to edit the file using rake tasks invar:config or invar:secrets?
                     MSG
                  end

            warn msg
            exit 1
         end
      end

      # Namespace module for task handler implementations
      module Task
         # Template config YAML file
         CONFIG_TEMPLATE = SECRETS_TEMPLATE = <<~YML
            ---
         YML

         CREATE_SUGGESTION = <<~SUGGESTION
            Maybe you used the wrong namespace or need to create the file with bundle exec rake invar:init?
         SUGGESTION
      end
   end
end
