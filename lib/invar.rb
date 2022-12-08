# frozen_string_literal: true

require 'invar/version'
require 'invar/file_locator'
require 'invar/scope'

require 'yaml'
require 'lockbox'
require 'pathname'
require 'dry/schema'

# Invar is a Ruby Gem that provides a single source of truth for application configuration and environment.
module Invar
   # Alias for Invar::Invar.new
   #
   # @see Invar.new
   def self.new(**args)
      Invar.new(**args)
   end

   # A wrapper for config and ENV variable data. It endeavours to limit your situation to a single source of truth.
   class Invar
      # Allowed permissions modes for lockfile. Readable or read-writable by the current user only
      ALLOWED_LOCKFILE_MODES = [0o600, 0o400].freeze

      # Name of the default key file to be searched for within config directories
      DEFAULT_KEY_FILE_NAME = 'master_key'

      # Constructs a new Invar.
      #
      # It will search for config, secrets, and decryption key files using the XDG specification.
      #
      # The secrets file is decrypted using Lockbox. The key will be requested from these locations in order:
      #
      #    1. the Lockbox.master_key variable
      #    2. the LOCKBOX_MASTER_KEY environment variable.
      #    3. saved in a secure key file (recommended)
      #    4. manual terminal prompt entry (recommended)
      #
      # The :decryption_keyfile argument specifies the filename to read for option 3. It will be searched for in
      # the same XDG locations as the secrets file. The decryption keyfile will be checked for safe permission modes.
      #
      # NEVER hardcode your encryption key. This class intentionally does not accept a raw string of your decryption
      # key to discourage hardcoding your encryption key and committing it to version control.
      #
      # @param [String] namespace name of the subdirectory within XDG locations
      # @param [#read] decryption_keyfile Any #read capable object referring to the decryption key file
      def initialize(namespace:, decryption_keyfile: nil, configs_schema: nil, secrets_schema: nil)
         locator      = FileLocator.new(namespace)
         search_paths = locator.search_paths.join(', ')

         begin
            @configs = Scope.new(load_configs(locator))
         rescue FileLocator::FileNotFoundError
            raise MissingConfigFileError,
                  "No config file found. Create config.yml in one of these locations: #{ search_paths }"
         end

         begin
            @secrets = Scope.new(load_secrets(locator, decryption_keyfile))
         rescue FileLocator::FileNotFoundError
            raise MissingSecretsFileError,
                  "No secrets file found. Create encrypted secrets.yml in one of these locations: #{ search_paths }"
         end

         freeze
         # instance_eval(&self.class.__override_block__)
         self.class.__override_block__&.call(self)

         validate_with configs_schema, secrets_schema
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
         file = locator.find('config', EXT::YAML)

         configs = parse(file.read)

         collision_key = configs.keys.collect(&:downcase).find { |key| env_hash.key? key }
         if collision_key
            hint = EnvConfigCollisionError::HINT
            raise EnvConfigCollisionError,
                  "Both the environment and your config file have key #{ collision_key }. #{ hint }"
         end

         configs.merge(env_hash)
      end

      def env_hash
         ENV.to_hash.transform_keys(&:downcase).transform_keys(&:to_sym)
      end

      def load_secrets(locator, decryption_keyfile)
         file = locator.find('secrets', EXT::YAML)

         lockbox = begin
                      decryption_key = Lockbox.master_key || resolve_key(decryption_keyfile, locator,
                                                                         "Enter master key to decrypt #{ file }:")

                      Lockbox.new(key: decryption_key)
                   rescue Lockbox::Error => e
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

      def resolve_key(pathname, locator, prompt)
         key_file = locator.find(pathname || DEFAULT_KEY_FILE_NAME)

         read_keyfile(key_file)
      rescue FileLocator::FileNotFoundError
         if $stdin.respond_to?(:noecho)
            warn prompt
            $stdin.noecho(&:gets).strip
         else
            raise SecretsFileDecryptionError,
                  "Could not find file '#{ pathname }'. Searched in: #{ locator.search_paths }"
         end
      end

      def read_keyfile(key_file)
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

         key_file.read.strip
      end

      def validate_with(configs_schema, secrets_schema)
         env_keys = env_hash.keys

         configs_schema ||= Dry::Schema.define

         # Special schema for just the env variables, listing them explicitly allows for using validate_keys
         env_schema = Dry::Schema.define do
            env_keys.each do |key|
               optional(key)
            end
         end

         schema = Dry::Schema.define do
            config.validate_keys = true

            required(:configs).hash(configs_schema & env_schema)

            if secrets_schema
               required(:secrets).hash(secrets_schema)
            else
               required(:secrets)
            end
         end

         validation = schema.call(configs: @configs.to_h,
                                  secrets: @secrets.to_h)

         return true if validation.success?

         errs = validation.errors.messages.collect do |message|
            [message.path.collect do |p|
               ":#{ p }"
            end.join(' / '), message.text].join(' ')
         end

         raise SchemaValidationError, <<~ERR
            Validation errors:
               #{ errs.join("\n   ") }
         ERR
      end
   end

   class << self
      # Block that will be run after loading from config files and prior to freezing. It is intended to allow
      # for test suites to tweak configurations without having to duplicate the entire config file.
      #
      # @yieldparam the configs from the Invar
      # @return [void]
      def after_load(&block)
         ::Invar::Invar.__override_block__ = block
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

   # Raised when #pretend is called but the testing extension has not been loaded.
   #
   # When raised during normal operation, it may mean the application is calling #pretend directly, which is strongly
   # discouraged. The feature is meant for testing.
   #
   # @see Invar#pretend
   class ImmutableRealityError < NoMethodError
      # Message and hint for a possible solution
      MSG = <<~MSG
         Method 'pretend' is defined in the testing extension. Try adding this to your test suite config file:
            require 'invar/test'
      MSG
   end

   # Raised when schema validation fails
   class SchemaValidationError < RuntimeError
   end
end
