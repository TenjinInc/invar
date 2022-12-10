# frozen_string_literal: true

require 'simplecov'

SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'invar'

# required to prevent "TypeError: superclass mismatch for class File" red herring when tests fail using FakeFS
require 'pp'

require 'fakefs/safe'
require 'fakefs/spec_helpers'

RSpec.configure do |config|
   config.include FakeFS::SpecHelpers
end
