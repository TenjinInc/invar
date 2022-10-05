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
      class InvalidAppNameError < ArgumentError
      end

      class MissingConfigFileError < RuntimeError
      end

      class MissingSecretsFileError < RuntimeError
      end

      class SecretsFileDecryptionError < RuntimeError
      end

      # Raised when there are config or secrets files found at multiple locations. You can resolve this by deciding on
      # one correct location and removing the alternate file(s).
      class AmbiguousSourceError < RuntimeError
         HINT = 'Choose 1 correct one and delete the others.'
      end

      class Envelope
         def initialize(namespace:, decryption_key: Lockbox.master_key)
            raise InvalidAppNameError, ':namespace cannot be nil' if namespace.nil?
            raise InvalidAppNameError, ':namespace cannot be an empty string' if namespace.empty?

            locator      = FileLocator.new(namespace)
            search_paths = locator.search_paths.join(', ')

            begin
               @configs = Scope.new(YAML.safe_load(locator.find('config', EXT::YAML).read, symbolize_names: true))
            rescue FileLocator::FileNotFoundError
               msg = "No config file found. Create config.yml in one of these locations: #{ search_paths }"
               raise MissingConfigFileError, msg
            end

            begin
               @secrets = Scope.new(load_secrets(locator.find('secrets', EXT::YAML), decryption_key))
            rescue FileLocator::FileNotFoundError
               msg = "No secrets file found. Create encrypted secrets.yml in one of these locations: #{ search_paths }"
               raise MissingSecretsFileError, msg
            end

            freeze

            # # TODO: setting & runninng override block should have some guards around it that raise if called after freezing
            # #       (with a better error msg, hint that it must be set) or if called too early
            # self.class.__override_block__&.call(@configs)
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
            when /configs?/
               @configs
            when /secrets?/
               @secrets
            else
               raise ArgumentError, 'The root scope name must be either :config or :secret.'
            end
         end

         alias / fetch
         alias [] fetch

         private

         def load_secrets(file, decryption_key)
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

            YAML.safe_load(file_data, symbolize_names: true)
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
