# frozen_string_literal: true

# Specifically not calling require 'invar' in this file to force applications to need to include it themselves,
# avoiding the situation where test suites include application dependencies for them and breaking when
# the app is run without the test suite

# :nodoc:
module Invar
   # Namespace module containing mixins for parts of the main gem to enable modifications and data control
   # in automated testing, while remaining immutable in the main gem and real runtime usage.
   module TestExtension
      # Methods to extend the Reality class
      module RealityMethods
         class << self
            attr_accessor :__after_load_hooks__

            RealityMethods.__after_load_hooks__ = []
         end

         def initialize(**)
            super

            # instance_eval(&self.class.__override_block__)
            RealityMethods.__after_load_hooks__.each { |hook| hook.call(self) }
         end
      end

      # Adds methods to the main Invar module itself for a global-access hook to be used in application init phase.
      module LoadHook
         def clear_hooks
            RealityMethods.__after_load_hooks__.clear
         end

         # Block that will be run after loading from config files.
         #
         # It is intended to allow test suites to tweak configurations without having to duplicate the entire config file.
         #
         # @yieldparam the configs from the Invar
         # @return [void]
         def after_load(&block)
            RealityMethods.__after_load_hooks__.push(block)
         end
      end

      # Methods mixin for the Invar::Scope class
      module ScopeMethods
         def initialize(data)
            @pretend_data = {}
            super
         end

         # Overrides the given set of key-value pairs. This is intended to only be used in testing environments,
         # where you may need contextual adjustments to suit the test situation.
         #
         # @param [Hash] pairs the hash of pairs to override.
         def pretend(pairs)
            @pretend_data.merge! convert(pairs)
         end

         def fetch(key)
            @pretend_data.fetch(key.downcase.to_sym) do
               super
            end
         rescue KeyError => e
            raise KeyError, "#{ e.message }. Pretend keys are: #{ pretend_keys }."
         end

         # Duplicated to refer to the override version
         alias / fetch
         alias [] fetch

         # Returns a hash representation of this scope and subscopes.
         #
         # @return [Hash] a hash representation of this scope
         def to_h
            super.merge(@pretend_data).to_h
         end

         private

         def pretend_keys
            keys = @pretend_data.keys

            if keys.empty?
               '(none)'
            else
               keys.sort.collect { |k| ":#{ k }" }.join(', ')
            end
         end
      end
   end

   # Extension to the base library class that provides additional methods relevant only to automated testing
   extend TestExtension::LoadHook

   # Extension to the base library class that provides additional methods relevant only to automated testing
   class Scope
      prepend TestExtension::ScopeMethods
   end

   class Reality
      prepend TestExtension::RealityMethods
   end
end
