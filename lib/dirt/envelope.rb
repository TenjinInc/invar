# frozen_string_literal: true

require 'dirt/envelope/version'
require 'yaml'
require 'lockbox'
require 'pathname'
require 'forwardable'

module Dirt

   # ENVelope
   module Envelope
      class InvalidAppNameError < ArgumentError
      end

      class MissingConfigFileError < RuntimeError
      end

      # Raised when there are multiple config files found. You can resolve this by choosing one correct location and
      # removing the alternate file.
      class AmbiguousSourceError < RuntimeError
      end

      # XDG values based on https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
      module XDG
         module Defaults
            CONFIG_HOME = '~/.config'
            CONFIG_DIRS = '/etc/xdg'
         end
      end

      module EXT
         YAML = '.yml'
      end

      class Envelope
         extend Forwardable

         def_delegators :@configs, :fetch, :/

         # def_delegator :@secrets, :secret, :fetch

         # attr_reader :configs, :secrets

         def initialize(namespace:)
            raise InvalidAppNameError, ':namespace cannot be nil' if namespace.nil?
            raise InvalidAppNameError, ':namespace cannot be an empty string' if namespace.empty?

            config_file = locate_file(namespace, :config)

            @configs = Envelope::Scope.new(YAML.safe_load(config_file&.read, symbolize_names: true))

            # secret_files = locate_files(namespace, :secrets)
            #
            # # TODO: this should be read from ENV or specific key in config file
            # master_key         = ENV.fetch('LOCKBOX_KEY') do
            #    raise KeyError, 'missing environment variable LOCKBOX_KEY' unless $stdin.respond_to? :noecho
            #    $stderr.puts 'Enter master key:'
            #    $stdin.noecho(&:gets).strip
            # end
            # Lockbox.master_key = master_key
            #
            # load_secrets(secret_files, master_key)
            #
            # # TODO: should be nice to recursively freeze secrets and configs, so that the whole settings hash chain is frozen
            # # secrets and main object are frozen prior to calling override block. This is on purpose to prevent folks from
            # # putting secrets into their code in that block.
            # @secrets.freeze
            # freeze
            #
            # # TODO: setting & runninng override block should have some guards around it that raise if called after freezing
            # #       (with a better error msg, hint that it must be set) or if called too early
            # self.class.__override_block__&.call(@configs)
            # @configs.freeze

            freeze
         end

         class << self
            attr_accessor :__override_block__
         end

         class Scope
            def initialize(data)
               @data = data || {}
               freeze
            end

            def fetch(key)
               value = @data.fetch(key.to_sym)

               if value.is_a? Hash
                  Scope.new(value)
               else
                  value
               end
            end

            alias / fetch
         end

         private

         def locate_file(namespace, filename)
            dirs = source_dirs(namespace)

            full_paths = dirs.collect { |dir| dir / "#{ filename }#{ EXT::YAML }" }

            files = full_paths.select(&:exist?)

            if files.size > 1
               msg = "Found more than 1 config file: #{ files.join(', ') }. Choose 1 correct one and delete the others."
               raise AmbiguousSourceError, msg
            elsif files.empty?
               msg = "No #{ filename } file found. Create config.yml in one of these locations: #{ dirs.join(', ') }"
               raise MissingConfigFileError, msg
            end

            files.first
         end

         def source_dirs(namespace)
            home_config_dir = ENV.fetch('XDG_CONFIG_HOME', XDG::Defaults::CONFIG_HOME)
            alt_config_dirs = ENV.fetch('XDG_CONFIG_DIRS', XDG::Defaults::CONFIG_DIRS).split(':')

            source_dirs = alt_config_dirs
            source_dirs.unshift(home_config_dir) if ENV.key? 'HOME'
            source_dirs.collect { |path| Pathname.new(path) / namespace }.collect(&:expand_path)
         end

         def load_secrets(files, master_key)
            # lockbox = Lockbox.new(key: master_key)
            #
            # # TODO: error out if any config files are readable by any other user
            #
            # files.each do |config_file|
            #    raw_file  = config_file.binread
            #    file_data = begin
            #                   lockbox.decrypt raw_file
            #                rescue Lockbox::DecryptionError => e
            #                   raise RuntimeError, "Failed to open #{ config_file } (#{ e })"
            #                end
            #    data      = YAML.safe_load(file_data, symbolize_names: true)
            #    next unless data
            #
            #    @secrets.merge!(data)
            # end
         end
      end

      class << self
         # Override block that will be run after loading from config files and prior to freezing. It is intended to allow
         # for test suites to tweak configurations without having to duplicate the entire config file.
         #
         # @yieldparam the configs from the Envelope
         # @return [void]
         def override(&block)
            ::Dirt::Envelope::Envelope.__override_block__ = block
         end
      end
   end
end
