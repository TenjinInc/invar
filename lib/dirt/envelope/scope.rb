# frozen_string_literal: true

module Dirt
   module Envelope
      class Scope
         def initialize(data = nil)
            @data = convert(data)

            @data.freeze
            @data_override = {}
            freeze
         end

         def fetch(key)
            @data_override.fetch(key.to_sym, @data.fetch(key.to_sym))
         end

         alias / fetch
         alias [] fetch

         def override(pairs)
            @data_override.merge!(pairs)
            @data_override.freeze
         end

         private

         def convert(data)
            (data || {}).dup.inject({}) do |agg, pair|
               key, value = pair

               agg[key] = value.is_a?(Hash) ? Scope.new(value) : value
               agg
            end
         end
      end
   end
end
