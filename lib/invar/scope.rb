# frozen_string_literal: true

module Invar
   # A set of configurations
   class Scope
      def initialize(data = nil)
         @data = convert(data)

         @data.freeze
         @data_override = {}
         freeze
      end

      # Retrieve the value for the given key
      #
      # @param [symbol] key
      # @raise KeyError if no such key exists.
      # @see #override
      def fetch(key)
         key = key.downcase.to_sym
         @data_override.fetch(key, @data.fetch(key))
      rescue KeyError => e
         raise KeyError, "#{ e.message }. Known keys are #{ @data.keys.sort.collect { |k| ":#{ k }" }.join(', ') }"
      end

      alias / fetch
      alias [] fetch

      def pretend(**)
         raise ::Invar::ImmutableRealityError, ::Invar::ImmutableRealityError::MSG
      end

      def to_h
         @data.merge(@data_override).to_h.transform_values do |value|
            case value
            when Scope
               value.to_h
            else
               value
            end
         end
      end

      def key?(key_name)
         to_h.key?(key_name)
      end

      private

      def convert(data)
         (data || {}).dup.each_with_object({}) do |pair, agg|
            key, value = pair

            agg[key] = value.is_a?(Hash) ? Scope.new(value) : value
         end
      end
   end
end