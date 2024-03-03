# frozen_string_literal: true

require 'invar/version'
require 'invar/scope'

require 'forwardable'

module Invar
   # Verifies a file is secure
   class PrivateFile
      extend Forwardable
      def_delegators :@delegate_sd_obj,
                     :stat, :to_s, :basename, :dirname, :extname, :==, :chmod, :rename, :write, :binwrite

      # Mask for limiting to the lowest three octal digits (which store permissions)
      PERMISSIONS_MASK = 0o777

      ALLOWED_USER_MODES  = [0o600, 0o400].freeze
      ALLOWED_GROUP_MODES = [0o060, 0o040, 0o000].freeze

      DEFAULT_PERMISSIONS = 0o600

      # Allowed permissions modes for lockfile. Readable or read-writable by the user or group only
      ALLOWED_MODES = ALLOWED_USER_MODES.product(ALLOWED_GROUP_MODES).collect do |u, g|
         u | g # bitwise OR
      end.freeze

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
         # stat             = @delegate_sd_obj.stat
         file_mode = stat.mode & PERMISSIONS_MASK
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
