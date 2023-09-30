# frozen_string_literal: true

require_relative 'namespaced'

module Invar
   module Rake
      module Task
         # Rake task handler for actions that just show information about the system
         class StatusHandler < NamespacedFileTask
            # Prints the current paths to be searched in
            def show_paths
               warn @locator.search_paths.join("\n")
            end
         end
      end
   end
end
