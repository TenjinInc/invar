# frozen_string_literal: true

require 'invar'

require 'rake'
require 'io/console'
require 'tempfile'

module Invar
   # Rake task implementation.
   #
   # The actual rake tasks themselves are thinly defined in invar/rake.rb (so that the external include
   # path is nice and short)
   module Rake
      # RakeTask builder class. Use Tasks.define to generate the needed tasks.
      class Tasks
         include ::Rake::Cloneable
         include ::Rake::DSL

         # Template config YAML file
         CONFIG_TEMPLATE = SECRETS_TEMPLATE = <<~YML
            ---
         YML

         CREATE_SUGGESTION = <<~SUGGESTION
            Maybe you used the wrong namespace or need to create the file with bundle exec rake invar:init?
         SUGGESTION

         # Shorthand for Invar::Rake::Tasks.new.define
         #
         # @param (see #define)
         # @see Tasks#define
         def self.define(**args, &block)
            new.define(**args, &block)
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
               define_secrets_task(app_namespace)

               define_info_tasks(app_namespace)
            end
         end

         def define_init_task(app_namespace)
            desc 'Create new configuration and encrypted secrets files'
            task :init, [:mode] do |_task, args|
               mode = args.mode

               config  = ::Invar::Rake::Tasks::ConfigTask.new(app_namespace)
               secrets = ::Invar::Rake::Tasks::SecretTask.new(app_namespace)

               case mode
               when 'config'
                  secrets = nil
               when 'secrets'
                  config = nil
               else
                  raise "unknown mode #{ mode }. Must be one of 'config' or 'secrets'" unless mode.nil?
               end

               assert_init_conditions(config&.file_path, secrets&.file_path)

               config&.create
               secrets&.create
            end
         end

         def define_config_task(app_namespace)
            desc 'Edit the config in your default editor'
            task :configs do
               ::Invar::Rake::Tasks::ConfigTask.new(app_namespace).edit
            end

            # alias
            task config: ['configs']
         end

         def define_secrets_task(app_namespace)
            desc 'Edit the encrypted secrets file in your default editor'
            task :secrets do
               ::Invar::Rake::Tasks::SecretTask.new(app_namespace).edit
            end

            # alias
            task secret: ['secrets']
         end

         def define_info_tasks(app_namespace)
            desc 'Show directories to be searched for the given namespace'
            task :paths do
               ::Invar::Rake::Tasks::StateTask.new(app_namespace).show_paths
            end
         end

         def assert_init_conditions(config_file, secrets_file)
            return unless config_file&.exist? || secrets_file&.exist?

            msg = if !config_file&.exist?
                     <<~MSG
                        Abort: Secrets file already exists (#{ secrets_file })
                        Run this to init only the config file: bundle exec rake tasks invar:init[config]
                     MSG
                  elsif !secrets_file&.exist?
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

         # Tasks that use a namespace for file searching
         class NamespacedTask
            def initialize(namespace)
               @locator = FileLocator.new(namespace)
            end

            def file_path
               config_dir / filename
            end

            private

            def config_dir
               @locator.search_paths.first
            end
         end

         # Configuration file actions.
         class ConfigTask < NamespacedTask
            # Creates a config file in the appropriate location
            def create
               raise 'File already exists' if file_path.exist?

               config_dir.mkpath
               file_path.write CONFIG_TEMPLATE
               file_path.chmod 0o600

               warn "Created file: #{ file_path }"
            end

            # Edits the existing config file in the appropriate location
            def edit
               configs_file = begin
                                 @locator.find('config.yml')
                              rescue ::Invar::FileLocator::FileNotFoundError => e
                                 warn <<~ERR
                                    Abort: #{ e.message }. Searched in: #{ @locator.search_paths.join(', ') }
                                    #{ CREATE_SUGGESTION }
                                 ERR
                                 exit 1
                              end

               system(ENV.fetch('EDITOR', 'editor'), configs_file.to_s, exception: true)

               warn "File saved to: #{ configs_file }"
            end

            private

            def filename
               'config.yml'
            end
         end

         # Secrets file actions.
         class SecretTask < NamespacedTask
            # Instructions hint for how to handle secret keys.
            SECRETS_INSTRUCTIONS = <<~INST
               Save this key to a secure password manager. You will need it to edit the secrets.yml file.
            INST

            # Creates a new encrypted secrets file and prints the generated encryption key to STDOUT
            def create
               raise 'File already exists' if file_path.exist?

               encryption_key = Lockbox.generate_key

               write_encrypted_file(file_path,
                                    encryption_key: encryption_key,
                                    content:        SECRETS_TEMPLATE,
                                    permissions:    PrivateFile::DEFAULT_PERMISSIONS)

               warn "Created file: #{ file_path }"

               warn SECRETS_INSTRUCTIONS
               warn 'Generated key is:'
               puts encryption_key
            end

            # Opens an editor for the decrypted contents of the secrets file. After closing the editor, the file will be
            # updated with the new encrypted contents.
            def edit
               secrets_file = begin
                                 @locator.find('secrets.yml')
                              rescue ::Invar::FileLocator::FileNotFoundError => e
                                 warn <<~ERR
                                    Abort: #{ e.message }. Searched in: #{ @locator.search_paths.join(', ') }
                                    #{ CREATE_SUGGESTION }
                                 ERR
                                 exit 1
                              end

               edit_encrypted_file(secrets_file)

               warn "File saved to #{ secrets_file }"
            end

            private

            def filename
               'secrets.yml'
            end

            def write_encrypted_file(file_path, encryption_key:, content:, permissions: nil)
               lockbox = Lockbox.new(key: encryption_key)

               encrypted_data = lockbox.encrypt(content)

               config_dir.mkpath
               # TODO: replace File.opens with photo_path.binwrite(uri.data) once FakeFS can handle it
               File.open(file_path.to_s, 'wb') { |f| f.write encrypted_data }
               file_path.chmod permissions if permissions
            end

            def edit_encrypted_file(file_path)
               encryption_key = determine_key(file_path)

               lockbox = build_lockbox(encryption_key)

               file_str = Tempfile.create(file_path.basename.to_s) do |tmp_file|
                  decrypted = lockbox.decrypt(file_path.binread)

                  tmp_file.write(decrypted)
                  tmp_file.rewind # rewind needed because file does not get closed after write
                  system(ENV.fetch('EDITOR', 'editor'), tmp_file.path, exception: true)
                  tmp_file.read
               end

               write_encrypted_file(file_path, encryption_key: encryption_key, content: file_str)
            end

            def determine_key(file_path)
               encryption_key = Lockbox.master_key

               if encryption_key.nil? && $stdin.respond_to?(:noecho)
                  warn "Enter master key to decrypt #{ file_path }:"
                  encryption_key = $stdin.noecho(&:gets).strip
               end

               encryption_key
            end

            def build_lockbox(encryption_key)
               Lockbox.new(key: encryption_key)
            rescue ArgumentError => e
               raise SecretsFileEncryptionError, e
            end
         end

         # General status tasks
         class StateTask < NamespacedTask
            # Prints the current paths to be searched in
            def show_paths
               warn @locator.search_paths.join("\n")
            end
         end
      end
   end
end
