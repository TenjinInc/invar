# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dirt/envelope/version'

Gem::Specification.new do |spec|
   spec.name    = 'dirt-envelope'
   spec.version = Dirt::Envelope::VERSION
   spec.authors = ['Robin Miller']
   spec.email   = ['robin@tenjin.ca']

   spec.summary     = %q{A nicer way to use environment variables. }
   spec.description = %q{Provides symbol access and namespacing for environment variables. }
   spec.homepage    = 'https://github.com/TenjinInc/dirt-envelope'
   spec.license     = 'MIT'

   spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
   spec.bindir        = 'exe'
   spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
   spec.require_paths = ['lib']

   spec.add_development_dependency 'bundler', '~> 1.11'
   spec.add_development_dependency 'rake', '~> 10.0'
   spec.add_development_dependency 'rspec', '~> 3.0'
   spec.add_development_dependency 'simplecov', '~> 0.11'
end
