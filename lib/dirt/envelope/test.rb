# frozen_string_literal: true

require 'dirt/envelope'

module Dirt
   # ENVelope
   module Envelope
      # Extension to the standard class
      class Scope
         # Overrides the given set of key-value pairs. This is intended to only be used in testing environments,
         # where you may need contextual adjustments to suit the test situation.
         #
         # @param [Hash] pairs the hash of pairs to override.
         def pretend(pairs)
            @data_override.merge!(pairs)
         end
      end
   end
end
