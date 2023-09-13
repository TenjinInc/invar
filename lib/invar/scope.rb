# frozen_string_literal: true

module Invar
   # A set of configurations
   class Scope
      def initialize(data = nil)
         @data = convert(data)

         @data.freeze
         freeze
      end

      # Retrieve the value for the given key
      #
      # @param [symbol] key
      # @raise KeyError if no such key exists.
      # @see #override
      def fetch(key)
         key = key.downcase.to_sym
         @data.fetch key
      rescue KeyError => e
         raise KeyError, "#{ e.message }. Known keys are #{ known_keys }"
      end

      alias / fetch
      alias [] fetch

      def method_missing(symbol, *args)
         raise ::Invar::ImmutableRealityError, ::Invar::ImmutableRealityError::PRETEND_MSG if symbol == :pretend

         super
      end

      # Returns a hash representation of this scope and subscopes.
      #
      # @return [Hash] a hash representation of this scope
      def to_h
         @data.to_h.transform_values do |value|
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

      def known_keys
         @data.keys.sort.collect { |k| ":#{ k }" }.join(', ')
      end

      def convert(data)
         (data || {}).dup.each_with_object({}) do |pair, agg|
            key, value = pair

            agg[key.to_s.downcase.to_sym] = value.is_a?(Hash) ? Scope.new(value) : value
         end
      end
   end
end
