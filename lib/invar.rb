# frozen_string_literal: true

# Needed for TTY input handling
# Do not remove; it missing will not always break tests due to test environments requiring it themselves
require 'io/console'

require_relative 'invar/version'
require_relative 'invar/errors'
require_relative 'invar/reality'

# Invar is a Ruby Gem that provides a single source of truth for application configuration, secrets, and environment
# variables.
module Invar
   # Alias for Invar::Reality.new
   #
   # @see Invar::Reality.new
   def self.new(**args)
      ::Invar::Reality.new(**args)
   end

   class << self
      def method_missing(method_name)
         guard_test_hooks method_name

         super
      end

      def respond_to_missing?(method_name, include_all)
         guard_test_hooks method_name

         super method_name, include_all
      end

      private

      def guard_test_hooks(method_name)
         return unless [:after_load, :clear_hooks].include? method_name

         raise ::Invar::ImmutableRealityError, ::Invar::ImmutableRealityError::HOOK_MSG
      end
   end
end
