# frozen_string_literal: true

require 'yaml'
require 'lockbox'
require 'pathname'
require 'dry/schema'

require 'invar/file_locator'
require 'invar/scope'

# :nodoc:
module Invar
   # Stores application config, secrets, and environmental variables. Environment variables come from ENV at the time of
   # instantiation, while configs and secrets are loaded from respective files in the appropriate location. The secrets
   # file is kept encrypted at rest.
   #
   # Fetch information from a Reality by using the slash operator or square brackets:
   #
   #    invar = Invar::Reality.new(namespace: 'test-app')
   #
   #    puts invar / :config / :database / :host
   #    puts invar[:config][:database][:host] # same as above
   #
   #    puts invar / :secrets / :database / :user
   #
   # Note: `Invar.new` is a shorthand for Invar::Reality.new
   #
   # Information known by a Reality is immutable. You may use the `#pretend` method to simulate different values during
   # testing.
   #
   #     # In your tests, define an after_load hook
   #    require 'invar/test'
   #    Invar.after_load do |reality|
   #       reality[:config][:database][:host].pretend 'example.com'
   #    end
   #
   #    # then later, in your app, it will use the pretend value
   #    invar = Invar.new namespace: 'my-app'
   #    puts invar / :config / :database / :host # prints example.com
   #
   # @see Invar.new
   # @see Reality#after_load
   # @see Reality#pretend
   class Reality
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
                  "No Invar config file found. Create config.yml in one of these locations: #{ search_paths }"
         end

         begin
            @secrets = Scope.new(load_secrets(locator, decryption_keyfile || DEFAULT_KEY_FILE_NAME))
         rescue FileLocator::FileNotFoundError
            hint = "Create encrypted secrets.yml in one of these locations: #{ search_paths }"
            raise MissingSecretsFileError,
                  "No Invar secrets file found. #{ hint }"
         end

         freeze

         RealityValidator.new(configs_schema, secrets_schema).validate(@configs, @secrets)
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

         configs  = parse(file.read)
         env_hash = ENV.to_hash.transform_keys(&:downcase).transform_keys(&:to_sym)

         collision_key = configs.keys.collect(&:downcase).find { |key| env_hash.key? key }
         if collision_key
            hint = EnvConfigCollisionError::HINT
            raise EnvConfigCollisionError,
                  "Both the environment and your config file have key #{ collision_key }. #{ hint }"
         end

         configs.merge(env_hash)
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
         key_file = locator.find(pathname)

         read_keyfile(key_file)
      rescue FileLocator::FileNotFoundError
         if $stdin.respond_to?(:noecho)
            warn prompt
            $stdin.noecho(&:gets).strip
         else
            raise SecretsFileDecryptionError,
                  "Could not find file '#{ pathname }'. Searched in: #{ locator.search_paths.join(', ') }"
         end
      end

      def read_keyfile(key_file)
         key_file.read.strip
      end

      # Validates a Reality object
      class RealityValidator
         def initialize(configs_schema, secrets_schema)
            configs_schema ||= Dry::Schema.define
            env_schema     = build_env_schema

            @schema = Dry::Schema.define do
               config.validate_keys = true

               required(:configs).hash(configs_schema & env_schema)

               if secrets_schema
                  required(:secrets).hash(secrets_schema)
               else
                  required(:secrets)
               end
            end
         end

         def validate(configs, secrets)
            validation = @schema.call(configs: configs.to_h,
                                      secrets: secrets.to_h)

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

         private

         # Special schema for just the env variables, listing them explicitly allows for using validate_keys
         def build_env_schema
            env_keys = ENV.to_hash.transform_keys(&:downcase).transform_keys(&:to_sym).keys
            Dry::Schema.define do
               env_keys.each do |key|
                  optional(key)
               end
            end
         end
      end
   end
end
