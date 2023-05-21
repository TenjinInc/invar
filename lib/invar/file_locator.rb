# frozen_string_literal: true

require 'invar/version'
require 'invar/scope'
require 'invar/private_file'

require 'yaml'
require 'lockbox'
require 'pathname'

module Invar
   # XDG values based on https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
   module XDG
      # Default values for various XDG variables
      module Defaults
         # Default XDG config directory within the user's $HOME.
         CONFIG_HOME = '~/.config'

         # Default XDG config direction within the broader system paths
         CONFIG_DIRS = '/etc/xdg'
      end
   end

   # Common file extension constants, excluding the dot.
   module EXT
      # File extension for YAML files
      YAML = 'yml'
   end

   # Locates a config file within XDG standard location(s) and namespace subdirectory.
   class FileLocator
      attr_reader :search_paths

      # Builds a new instance that will search in the namespace.
      #
      # @param [String] namespace Name of the subdirectory within the XDG standard location(s)
      # @raise [InvalidNamespaceError] if the namespace is nil or empty string
      def initialize(namespace)
         raise InvalidNamespaceError, 'namespace cannot be nil' if namespace.nil?
         raise InvalidNamespaceError, 'namespace cannot be an empty string' if namespace.empty?

         @namespace = namespace

         home_config_dir = ENV.fetch('XDG_CONFIG_HOME', XDG::Defaults::CONFIG_HOME)
         alt_config_dirs = ENV.fetch('XDG_CONFIG_DIRS', XDG::Defaults::CONFIG_DIRS).split(':')

         source_dirs = alt_config_dirs
         source_dirs.unshift(home_config_dir) if ENV.key? 'HOME'
         @search_paths = source_dirs.collect { |path| Pathname.new(path) / @namespace }.collect(&:expand_path)

         freeze
      end

      # Locates the file with the given same. You may optionally provide an extension as a second argument.
      #
      # These are equivalent:
      #    find('config.yml')
      #    find('config', 'yml')
      #
      # @param [String] basename The file's basename
      # @param [String] ext the file extension, excluding the dot.
      # @return [PrivateFile] the path of the located file
      # @raise [AmbiguousSourceError] if the file is found in multiple locations
      # @raise [FileNotFoundError] if the file cannot be found
      def find(basename, ext = nil)
         basename = [basename, ext].join('.') if ext

         full_paths = search_paths.collect { |dir| dir / basename }
         files      = full_paths.select(&:exist?)

         if files.size > 1
            msg = "Found more than 1 #{ basename } file: #{ files.join(', ') }."
            raise AmbiguousSourceError, "#{ msg } #{ AmbiguousSourceError::HINT }"
         end

         PrivateFile.new(files.first || raise(FileNotFoundError, "Could not find #{ basename }"))
      end

      # Raised when the file cannot be found in any of the XDG search locations.
      class FileNotFoundError < RuntimeError
      end

      # Raised when the provided namespace is invalid.
      class InvalidNamespaceError < ArgumentError
      end
   end
end
