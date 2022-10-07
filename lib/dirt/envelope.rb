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
      class MissingConfigFileError < RuntimeError
      end

      class MissingSecretsFileError < RuntimeError
      end

      class SecretsFileEncryptionError < RuntimeError
      end

      class SecretsFileDecryptionError < RuntimeError
      end

      class EnvConfigCollisionError < RuntimeError
         HINT = 'Either rename your config entry or remove the environment variable.'
      end

      # Raised when there are config or secrets files found at multiple locations. You can resolve this by deciding on
      # one correct location and removing the alternate file(s).
      class AmbiguousSourceError < RuntimeError
         HINT = 'Choose 1 correct one and delete the others.'
      end

      class Envelope
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

            # TODO: setting & runninng override block should have some guards around it that raise if called after freezing
            #       (with a better error msg, hint that it must be set) or if called too early
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

            if decryption_key.nil? && $stdin.respond_to?(:noecho)
               warn "Enter master key to decrypt #{ file }:"
               decryption_key = $stdin.noecho(&:gets).strip
            end

            lockbox = begin
                         Lockbox.new(key: decryption_key)
                      rescue ArgumentError => e
                         raise SecretsFileDecryptionError, e
                      end

            # TODO: error out if any config files are readable by any other user

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
   end
end
