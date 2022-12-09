# frozen_string_literal: true

require 'simplecov'

SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'invar'

require 'fakefs/safe'
require 'fakefs/spec_helpers'

RSpec.configure do |config|
   config.include FakeFS::SpecHelpers
end
