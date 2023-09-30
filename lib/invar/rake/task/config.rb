# frozen_string_literal: true

require_relative 'namespaced'

module Invar
   module Rake
      module Task
         # Rake task handler for actions to do with configuration files
         class ConfigFileHandler < NamespacedFileTask
            # Creates a config file in the appropriate location
            def create
               config_dir.mkpath
               file_path.write CONFIG_TEMPLATE
               file_path.chmod 0o600

               warn "Created file: #{ file_path }"
            end

            # Edits the existing config file in the appropriate location
            def edit
               content   = $stdin.stat.pipe? ? $stdin.read : nil
               file_path = configs_file

               if content
                  file_path.write content
               else
                  system ENV.fetch('EDITOR', 'editor'), file_path.to_s, exception: true
               end

               warn "File saved to: #{ file_path }"
            end

            private

            def configs_file
               @locator.find 'config.yml'
            rescue ::Invar::FileLocator::FileNotFoundError => e
               warn <<~ERR
                  Abort: #{ e.message }. Searched in: #{ @locator.search_paths.join(', ') }
                  #{ CREATE_SUGGESTION }
               ERR
               exit 1
            end

            def filename
               'config.yml'
            end
         end
      end
   end
end
