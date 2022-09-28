# frozen_string_literal: true

require 'dirt/envelope/version'
require 'yaml'
require 'lockbox'
require 'pathname'
require 'forwardable'

module Dirt

   # ENVelope
   module Envelope
      # TODO: replace PATH_KEY and DEFAULT_PATH with XDG gem. won't need them then
      PATH_KEY = 'ENVELOPE_PATH'
      # specifically not looking in app directory since we want to discourage saving any of these in git
      DEFAULT_PATH = %w[
         /etc
         /usr/local/etc
         ~/.config
      ].join(' ').freeze

      EXT = '.yml'

      class Envelope
         extend Forwardable

         def_delegators :@configs, :fetch, :[]

         def_delegator :@secrets, :secret, :fetch

         attr_reader :configs, :secrets

         def initialize(app_name:)
            @configs = {}
            @secrets = {}

            config_files = locate_files(app_name, :config)

            load_configs(config_files)

            secret_files = locate_files(app_name, :secrets)

            # TODO: this should be read from ENV or specific key in config file
            master_key         = ENV.fetch('LOCKBOX_KEY') do
               raise KeyError, 'missing environment variable LOCKBOX_KEY' unless $stdin.respond_to? :noecho
               $stderr.puts 'Enter master key:'
               $stdin.noecho(&:gets).strip
            end
            Lockbox.master_key = master_key

            load_secrets(secret_files, master_key)

            # TODO: should be nice to recursively freeze secrets and configs, so that the whole settings hash chain is frozen
            # secrets and main object are frozen prior to calling override block. This is on purpose to prevent folks from
            # putting secrets into their code in that block.
            @secrets.freeze
            freeze

            # TODO: setting & runninng override block should have some guards around it that raise if called after freezing
            #       (with a better error msg, hint that it must be set) or if called too early
            self.class.__override_block__&.call(@configs)
            @configs.freeze
         end

         class << self
            attr_accessor :__override_block__
         end

         private

         def search_path
            ENV.fetch(PATH_KEY, DEFAULT_PATH).split(/\s+/).collect { |path| Pathname.new(path).expand_path }
         end

         def load_configs(files)
            files.each do |config_file|
               data = YAML.safe_load(config_file.read, symbolize_names: true)
               next unless data

               @configs.merge!(data)
            end
         end

         def load_secrets(files, master_key)
            lockbox = Lockbox.new(key: master_key)

            # TODO: error out if any config files are readable by any other user

            files.each do |config_file|
               raw_file  = config_file.binread
               file_data = begin
                              lockbox.decrypt raw_file
                           rescue Lockbox::DecryptionError => e
                              raise RuntimeError, "Failed to open #{ config_file } (#{ e })"
                           end
               data      = YAML.safe_load(file_data, symbolize_names: true)
               next unless data

               @secrets.merge!(data)
            end
         end

         def locate_files(app_name, type)
            full_paths = search_path.collect { |dir| dir / app_name / "#{ type }#{ EXT }" }.collect(&:expand_path)

            config_files = full_paths.select(&:exist?)

            if config_files.empty?
               raise "No #{ type } files found. Looked for: #{ full_paths.join(', ') }. Create at least one of these."
            end

            config_files
         end

         class SettingSet
            extend Forwardable

            def_delegators :@config, :fetch, :[]

            def_delegator :@secrets, :secret, :fetch

            def initialize(config)
               @config  = config
               @secrets = {}
            end

            def merge!(other)
               if other.is_a? Hash
                  @delegate_sd_obj.merge!(SettingSet.new(other))
               else
                  @delegate_sd_obj.merge!(other)
               end
            end
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
