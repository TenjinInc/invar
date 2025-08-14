# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'invar/version'

Gem::Specification.new do |spec|
   spec.name    = 'invar'
   spec.version = Invar::VERSION
   spec.authors = ['Robin Miller']
   spec.email   = ['robin@tenjin.ca']

   spec.summary     = 'Single source of truth for environmental configuration.'
   spec.description = <<~DESC
      Locates and loads config YAML files based on XDG standard with the encrypted secrets file kept separately.
      Includes useful rake tasks to make management easier. No code execution in config. Rails-independent. Gluten free.
   DESC
   spec.homepage = 'https://github.com/TenjinInc/invar'
   spec.license  = 'MIT'
   spec.metadata = {
         'rubygems_mfa_required' => 'true'
   }

   spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
   spec.bindir        = 'exe'
   spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
   spec.require_paths = ['lib']

   spec.required_ruby_version = '>= 3.1'

   spec.add_dependency 'dry-schema', '>= 1.0'
   spec.add_dependency 'lockbox', '>= 2.0'
end
