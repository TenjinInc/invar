# frozen_string_literal: true

require 'simplecov'

SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'dirt/envelope'

# Intentionally kept separate from main lib require so that folks can use the rake tasks optionally
require 'dirt/envelope/rake'

require 'pp' # needed to fix a conflict with FakeFS
require 'fakefs/safe'
require 'fakefs/spec_helpers'

RSpec.configure do |config|
   config.include FakeFS::SpecHelpers
end
