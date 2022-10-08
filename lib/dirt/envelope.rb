# frozen_string_literal: true

require 'dirt/envelope/version'
require 'dirt/envelope/file_locator'
require 'dirt/envelope/scope'

require 'yaml'
require 'lockbox'
require 'pathname'

module Dirt
   # ENVelope
   module Envelope
      class Envelope
         # Allowed permissions modes for lockfile. Readable or read-writable by the current user only
         ALLOWED_LOCKFILE_MODES = [0o600, 0o400].freeze

         # Constructs a new Envelope.
         #
         # @param [String] namespace name of the subdirectory within XDG locations
         # @param [String, #to_path] decryption_key Either the raw decryption key string or a #to_path capable object
         #                                          and assumed to be a file name.
         def initialize(namespace:, decryption_key: Lockbox.master_key)
            locator      = FileLocator.new(namespace)
            search_paths = locator.search_paths.join(', ')

            begin
               @configs = Scope.new(load_configs(locator))
            rescue FileLocator::FileNotFoundError
               raise MissingConfigFileError,
                     "No config file found. Create config.yml in one of these locations: #{ search_paths }"
            end

            begin
               @secrets = Scope.new(load_secrets(locator, decryption_key))
            rescue FileLocator::FileNotFoundError
               raise MissingSecretsFileError,
                     "No secrets file found. Create encrypted secrets.yml in one of these locations: #{ search_paths }"
            end

            freeze

            # instance_eval(&self.class.__override_block__)
            self.class.__override_block__&.call(self)
         end

         class << self
            attr_accessor :__override_block__
         end

         # Fetch from one of the two base scopes: :config or :secret.
         # Plural names are also accepted (ie. :configs and :secrets).
         #
         # @param base_scope [Symbol, String]
         def fetch(base_scope)
            case base_scope
            when /configs?/i
               @configs
            when /secrets?/i
               @secrets
            else
               raise ArgumentError, 'The root scope name must be either :config or :secret.'
            end
         end

         alias / fetch
         alias [] fetch

         private

         def load_configs(locator)
            env = ENV.to_hash.transform_keys(&:downcase).transform_keys(&:to_sym)

            file = locator.find('config', EXT::YAML)

            configs = parse(file.read)

            collision_key = configs.keys.collect(&:downcase).find { |key| env.key? key }
            if collision_key
               hint = EnvConfigCollisionError::HINT
               raise EnvConfigCollisionError,
                     "Both the environment and your config file have key #{ collision_key }. #{ hint }"
            end

            configs.merge(env)
         end

         def load_secrets(locator, decryption_key)
            file = locator.find('secrets', EXT::YAML)

            lockbox = begin
                         Lockbox.new(key: resolve_key(decryption_key, locator,
                                                      "Enter master key to decrypt #{ file }:"))
                      rescue ArgumentError => e
                         raise SecretsFileDecryptionError, e
                      end

            bytes     = file.binread
            file_data = begin
                           lockbox.decrypt bytes
                        rescue Lockbox::DecryptionError => e
                           hint = 'Perhaps you used the wrong file decryption key?'
                           raise SecretsFileDecryptionError, "Failed to open #{ file } (#{ e }). #{ hint }"
                        end

            parse(file_data)
         end

         def parse(file_data)
            YAML.safe_load(file_data, symbolize_names: true) || {}
         end

         def resolve_key(decryption_key, locator, prompt)
            if decryption_key.nil? && $stdin.respond_to?(:noecho)
               warn prompt
               $stdin.noecho(&:gets).strip
            elsif decryption_key.respond_to? :to_path
               read_keyfile(locator, decryption_key)
            else
               decryption_key
            end
         end

         def read_keyfile(locator, pathname)
            key_file = begin
                          locator.find(pathname.to_path)
                       rescue FileLocator::FileNotFoundError
                          raise SecretsFileDecryptionError,
                                "Could not find file '#{ pathname }'. Searched in: #{ locator.search_paths }"
                       end

            permissions_mask = 0o777 # only the lowest three digits are perms, so masking
            stat             = key_file.stat
            file_mode        = stat.mode & permissions_mask
            # TODO: use stat.world_readable? etc instead
            unless ALLOWED_LOCKFILE_MODES.include? file_mode
               hint = "Try: chmod 600 #{ key_file }"
               raise SecretsFileDecryptionError,
                     format("File '%<path>s' has improper permissions (%<mode>04o). %<hint>s",
                            path: key_file,
                            mode: file_mode,
                            hint: hint)
            end

            key_file.read
         end
      end

      class << self
         # Block that will be run after loading from config files and prior to freezing. It is intended to allow
         # for test suites to tweak configurations without having to duplicate the entire config file.
         #
         # @yieldparam the configs from the Envelope
         # @return [void]
         def after_load(&block)
            ::Dirt::Envelope::Envelope.__override_block__ = block
         end
      end

      # Raised when no config file can be found within the search paths.
      class MissingConfigFileError < RuntimeError
      end

      # Raised when no secrets file can be found within the search paths.
      class MissingSecretsFileError < RuntimeError
      end

      # Raised when an error is encountered during secrets file encryption
      class SecretsFileEncryptionError < RuntimeError
      end

      # Raised when an error is encountered during secrets file decryption
      class SecretsFileDecryptionError < RuntimeError
      end

      # Raised when a key is defined in both the environment and the configuration file.
      class EnvConfigCollisionError < RuntimeError
         # Message hinting at possible solution
         HINT = 'Either rename your config entry or remove the environment variable.'
      end

      # Raised when there are config or secrets files found at multiple locations. You can resolve this by deciding on
      # one correct location and removing the alternate file(s).
      class AmbiguousSourceError < RuntimeError
         # Message hinting at possible solution
         HINT = 'Choose 1 correct one and delete the others.'
      end
   end
end
