# frozen_string_literal: true

require 'simplecov'

SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'invar'

module SpecHelpers
   TEST_TMP_ROOT = Pathname.new(Dir.mktmpdir('invar_test_')).expand_path.freeze

   # Runs the given block in a context where STDIN is connected to a pipe containing the given input string
   #
   # @param input_string - String to feed into the pipe
   # @yield - context to run under the piped connection
   def with_pipe_input(input_string)
      original_stdin = $stdin

      IO.pipe do |reader, writer|
         $stdin = reader
         writer.puts input_string
         writer.close # signal that the input is totes dunzo
         yield
      end

      $stdin = original_stdin
   end

   # Runs the given block with the specified `Lockbox.master_key`
   #
   # @param key - The key to feed to Lockbox
   def with_lockbox_key(key)
      original_key = Lockbox.master_key

      Lockbox.master_key = key
      yield
      Lockbox.master_key = original_key
   end

   def test_safe_path(original_path)
      original_path = Pathname.new(original_path).expand_path

      relative_path = original_path.absolute? ? original_path.relative_path_from('/') : original_path

      SpecHelpers::TEST_TMP_ROOT / relative_path
   end

   def with_env(new_env)
      old_env = {}
      new_env.each do |key, value|
         old_env[key] = ENV.fetch(key, nil)
         ENV[key]     = value
      end
      yield
      # reset
      old_env.each do |key, value|
         ENV[key] = value
      end
   end

   def self.included(example_group)
      # Wipe out the test files after each step
      example_group.after :each do
         TEST_TMP_ROOT.each_child(&:rmtree)
      end
   end
end

RSpec.configure do |config|
   config.include SpecHelpers
end
