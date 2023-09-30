# frozen_string_literal: true

require_relative '../tasks'

module Invar
   module Rake
      module Task
         # Abstract class for tasks that use a namespace for file searching
         class NamespacedFileTask
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
      end
   end
end
