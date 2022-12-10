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
               define_config_tasks(app_namespace)
               define_secrets_tasks(app_namespace)

               define_info_tasks(app_namespace)
            end
         end

         def define_config_tasks(app_namespace)
            namespace :configs do
               desc 'Create a new configuration file'
               task :create do
                  ::Invar::Rake::Tasks::ConfigTask.new(app_namespace).create
               end

               desc 'Edit the config in your default editor'
               task :edit do
                  ::Invar::Rake::Tasks::ConfigTask.new(app_namespace).edit
               end
            end

            # alias
            namespace :config do
               task create: ['configs:create']
               task edit: ['configs:edit']
            end
         end

         def define_secrets_tasks(app_namespace)
            namespace :secrets do
               desc 'Create a new encrypted secrets file'
               task :create do
                  ::Invar::Rake::Tasks::SecretTask.new(app_namespace).create
               end

               desc 'Edit the encrypted secrets file in your default editor'
               task :edit do
                  ::Invar::Rake::Tasks::SecretTask.new(app_namespace).edit
               end
            end

            # alias
            namespace :secret do
               task create: ['secrets:create']
               task edit: ['secrets:edit']
            end
         end

         def define_info_tasks(app_namespace)
            desc 'Show directories to be searched for the given namespace'
            task :paths do
               ::Invar::Rake::Tasks::StateTask.new(app_namespace).show_paths
            end
         end

         # Tasks that use a namespace for file searching
         class NamespacedTask
            def initialize(namespace)
               @locator = FileLocator.new(namespace)
            end
         end

         # Configuration file actions.
         class ConfigTask < NamespacedTask
            # Creates a config file in the appropriate location
            def create
               config_dir = @locator.search_paths.first
               config_dir.mkpath

               file = config_dir / 'config.yml'
               if file.exist?
                  warn <<~MSG
                     Abort: File exists. (#{ file })
                     Maybe you meant to edit the file with bundle exec rake invar:secrets:edit?
                  MSG
                  exit 1
               end

               file.write CONFIG_TEMPLATE

               warn "Created file: #{ file }"
            end

            # Edits the existing config file in the appropriate location
            def edit
               configs_file = begin
                                 @locator.find('config.yml')
                              rescue ::Invar::FileLocator::FileNotFoundError => e
                                 warn <<~ERR
                                    Abort: #{ e.message }. Searched in: #{ @locator.search_paths.join(', ') }
                                    Maybe you used the wrong namespace or need to create the file with bundle exec rake invar:configs:create?
                                 ERR
                                 exit 1
                              end

               system(ENV.fetch('EDITOR', 'editor'), configs_file.to_s, exception: true)

               warn "File saved to: #{ configs_file }"
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
               config_dir = @locator.search_paths.first
               config_dir.mkpath

               file = config_dir / 'secrets.yml'

               if file.exist?
                  warn <<~ERR
                     Abort: File exists. (#{ file })
                     Maybe you meant to edit the file with bundle exec rake invar:secrets:edit?
                  ERR
                  exit 1
               end

               encryption_key = Lockbox.generate_key

               write_encrypted_file(file, encryption_key, SECRETS_TEMPLATE)

               warn "Created file #{ file }"

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
                                    Maybe you used the wrong namespace or need to create the file with bundle exec rake invar:secrets:create?
                                 ERR
                                 exit 1
                              end

               edit_encrypted_file(secrets_file)

               warn "File saved to #{ secrets_file }"
            end

            private

            def write_encrypted_file(file_path, encryption_key, content)
               lockbox = Lockbox.new(key: encryption_key)

               encrypted_data = lockbox.encrypt(content)

               # TODO: replace File.opens with photo_path.binwrite(uri.data) once FakeFS can handle it
               File.open(file_path.to_s, 'wb') { |f| f.write encrypted_data }
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

               write_encrypted_file(file_path, encryption_key, file_str)
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

