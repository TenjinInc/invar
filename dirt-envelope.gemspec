# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dirt/envelope/version'

Gem::Specification.new do |spec|
   spec.name    = 'dirt-envelope'
   spec.version = Dirt::Envelope::VERSION
   spec.authors = ['Robin Miller']
   spec.email   = ['robin@tenjin.ca']

   spec.summary     = %q{Unified environment config.}
   spec.description = %q{Provides symbol access and namespacing for environment variables. }
   spec.homepage    = 'https://github.com/TenjinInc/dirt-envelope'
   spec.license     = 'MIT'
   spec.metadata    = {
         'rubygems_mfa_required' => 'true'
   }

   spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
   spec.bindir        = 'exe'
   spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
   spec.require_paths = ['lib']

   spec.add_dependency 'lockbox', '>= 1.0'

   spec.add_development_dependency 'bundler', '~> 2.3'
   spec.add_development_dependency 'rake', '~> 13.0'
   spec.add_development_dependency 'rspec', '~> 3.9'
   spec.add_development_dependency 'simplecov', '~> 0.21'
   spec.add_development_dependency 'fakefs', '~> 1.8'
   spec.add_development_dependency 'yard', '~> 0.9'
end
