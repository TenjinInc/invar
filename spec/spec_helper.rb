# frozen_string_literal: true

require 'simplecov'

SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'invar'

# required to prevent "TypeError: superclass mismatch for class File" red herring when tests fail using FakeFS
require 'pp'

require 'fakefs/safe'
require 'fakefs/spec_helpers'

module SpecHelpers
   def with_pipe_input(input)
      original_stdin = $stdin

      IO.pipe do |reader, writer|
         $stdin = reader
         writer.puts input
         writer.close # signal that input is totes dunzo
         yield
      end

      $stdin = original_stdin
   end
end

RSpec.configure do |config|
   config.include FakeFS::SpecHelpers

   config.include SpecHelpers
end
