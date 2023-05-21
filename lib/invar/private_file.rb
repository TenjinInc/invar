# frozen_string_literal: true

require 'invar/version'
require 'invar/scope'

require 'delegate'

module Invar
   # Verifies a file is secure
   class PrivateFile #< SimpleDelegator
      extend Forwardable
      def_delegators :@delegate_sd_obj, :stat, :to_s, :basename, :==, :chmod

      # Allowed permissions modes for lockfile. Readable or read-writable by the user or group only
      ALLOWED_MODES = [0o600, 0o400, 0o060, 0o040].freeze

      def initialize(file_path)
         @delegate_sd_obj = file_path
      end

      def read(**args)
         verify_permissions!

         @delegate_sd_obj.read(**args)
      end

      def binread(**args)
         verify_permissions!

         @delegate_sd_obj.binread(**args)
      end

      # Raised when the file has improper permissions
      class FilePermissionsError < RuntimeError
      end

      private

      # Verifies the file has proper permissions
      #
      # @raise [FilePermissionsError] if the file has insecure permissions
      def verify_permissions!
         permissions_mask = 0o777 # only the lowest three digits are perms, so masking
         # stat             = @delegate_sd_obj.stat
         file_mode = stat.mode & permissions_mask
         # TODO: use stat.world_readable? etc instead
         return if ALLOWED_MODES.include? file_mode

         msg = format("File '%<path>s' has improper permissions (%<mode>04o). %<hint>s",
                      path: @delegate_sd_obj,
                      mode: file_mode,
                      hint: "Try: chmod 600 #{ @delegate_sd_obj }")

         raise FilePermissionsError, msg
      end
   end
end
