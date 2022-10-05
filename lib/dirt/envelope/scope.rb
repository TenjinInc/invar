# frozen_string_literal: true

module Dirt
   module Envelope
      class Scope
         def initialize(data = nil)
            @data = data || {}
            freeze
         end

         def fetch(key)
            value = @data.fetch(key.to_sym)

            if value.is_a? Hash
               Scope.new(value)
            else
               value
            end
         end

         alias / fetch
         alias [] fetch
      end
   end
end
