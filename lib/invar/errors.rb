module Invar

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
      HINT = <<~HINT
         Try adding this to your test suite config file:
            require 'invar/test'
      HINT

      PRETEND_MSG = "Method 'Invar::Scope#pretend' is defined in the testing extension. #{ HINT }"
      HOOK_MSG    = "Method 'Invar.after_load' is defined in the testing extension. #{ HINT }"
   end

   # Raised when schema validation fails
   class SchemaValidationError < RuntimeError
   end
end