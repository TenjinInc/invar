# frozen_string_literal: true

require 'dirt/envelope/version'
require 'dirt/envelope/scope'

require 'yaml'
require 'lockbox'
require 'pathname'

module Dirt

   # ENVelope
   module Envelope
      # XDG values based on https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
      module XDG
         module Defaults
            CONFIG_HOME = '~/.config'
            CONFIG_DIRS = '/etc/xdg'
         end
      end

      # Common file extension constants
      module EXT
         # File extension for YAML files
         YAML = '.yml'
      end

      class FileLocator
         attr_reader :search_paths

         def initialize(namespace)
            @namespace = namespace

            home_config_dir = ENV.fetch('XDG_CONFIG_HOME', XDG::Defaults::CONFIG_HOME)
            alt_config_dirs = ENV.fetch('XDG_CONFIG_DIRS', XDG::Defaults::CONFIG_DIRS).split(':')

            source_dirs = alt_config_dirs
            source_dirs.unshift(home_config_dir) if ENV.key? 'HOME'
            @search_paths = source_dirs.collect { |path| Pathname.new(path) / @namespace }.collect(&:expand_path)

            freeze
         end

         def find(basename, ext = '')
            full_paths = search_paths.collect { |dir| dir / "#{ basename }#{ ext }" }

            files = full_paths.select(&:exist?)

            if files.size > 1
               msg = "Found more than 1 #{ basename } file: #{ files.join(', ') }."
               raise AmbiguousSourceError, "#{ msg } #{ AmbiguousSourceError::HINT }"
            end

            files.first || raise(FileNotFoundError, "Could not find #{ basename }")
         end

         class FileNotFoundError < RuntimeError
         end
      end
   end
end
