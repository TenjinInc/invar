# frozen_string_literal: true

module Dirt
   module Envelope
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

         # Overrides the given set of key-value pairs. This is intended to only be used in testing environments,
         # where you may need contextual adjustments to suit the test situation.
         #
         # @param [Hash] pairs the hash of pairs to override.
         def override(pairs)
            @data_override.merge!(pairs)
            @data_override.freeze
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
end
