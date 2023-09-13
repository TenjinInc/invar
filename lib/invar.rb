# frozen_string_literal: true

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
      def method_missing(meth)
         if [:after_load, :clear_hooks].include? meth
            raise ::Invar::ImmutableRealityError, ::Invar::ImmutableRealityError::HOOK_MSG
         end

         super
      end
   end
end
