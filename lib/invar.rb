# frozen_string_literal: true

require_relative 'invar/version'
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
      # Block that will be run after loading from config files and prior to freezing. It is intended to allow
      # for test suites to tweak configurations without having to duplicate the entire config file.
      #
      # @yieldparam the configs from the Invar
      # @return [void]
      def after_load(&block)
         ::Invar::Reality.__override_block__ = block
      end
   end
end
