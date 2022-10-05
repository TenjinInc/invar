# frozen_string_literal: true

require 'spec_helper'

module Dirt
   module Envelope
      describe FileLocator do
         let(:namespace) { 'test-app' }

         describe '#initialize' do
            let(:locator) { described_class.new namespace }

            around(:each) do |example|
               # store original values
               old_xdg_config_home = ENV.fetch('XDG_CONFIG_HOME', nil)
               old_xdg_config_dirs = ENV.fetch('XDG_CONFIG_DIRS', nil)

               # actual test setup
               ENV.delete('XDG_CONFIG_HOME')
               ENV.delete('XDG_CONFIG_DIRS')
               example.run

               # reset original values
               ENV['XDG_CONFIG_HOME'] = old_xdg_config_home
               ENV['XDG_CONFIG_DIRS'] = old_xdg_config_dirs
            end

            it 'should explode when provided an empty namespace' do
               expect do
                  described_class.new ''
               end.to raise_error FileLocator::InvalidNamespaceError, 'namespace cannot be an empty string'
            end

            it 'should explode when provided a nil namespace' do
               expect do
                  described_class.new nil
               end.to raise_error FileLocator::InvalidNamespaceError, 'namespace cannot be nil'
            end

            # This is so that it does not change behaviour if env variables are changed after it is loaded.
            it 'should be frozen' do
               expect(locator).to be_frozen
            end

            it 'should compute a list of paths' do
               expect(locator.search_paths).to include(instance_of(Pathname))
            end

            it 'should namespace the paths with the app namespace' do
               locator.search_paths.each do |search_path|
                  expect(search_path.basename.to_s).to eq namespace
               end
            end

            context '$HOME is defined' do
               let(:home) { Pathname.new '/some/home/path' }

               around(:each) do |example|
                  old_home    = Dir.home
                  ENV['HOME'] = home.to_s
                  example.run
                  ENV['HOME'] = old_home
               end

               it 'should search in XDG_CONFIG_HOME' do
                  config_root            = Pathname.new '/an_alternate/home-config/path'
                  ENV['XDG_CONFIG_HOME'] = config_root.to_s

                  expect(locator.search_paths).to start_with(config_root / namespace)
               end

               # Standard defines default as "$HOME/.config"
               it 'should default unbound XDG_CONFIG_HOME to default from XDG standard' do
                  config_root = Pathname.new('~/.config').expand_path
                  ENV.delete('XDG_CONFIG_HOME')

                  expect(locator.search_paths).to start_with(config_root / namespace)
               end
            end

            context '$HOME is undefined' do
               around(:each) do |example|
                  old_home = Dir.home
                  ENV.delete('HOME')
                  example.run
                  ENV['HOME'] = old_home
               end

               # Config dirs are a colon-separated priority list
               it 'should search in any XDG_CONFIG_DIRS directory' do
                  config_dirs            = %w[/an_alternate/home /config/path]
                  ENV['XDG_CONFIG_DIRS'] = config_dirs.join(':')

                  expect(locator.search_paths.length).to eq 2
                  expect(locator.search_paths.first).to eq Pathname.new(config_dirs.first) / namespace
                  expect(locator.search_paths.last).to eq Pathname.new(config_dirs.last) / namespace
               end

               # Standard defines default as "/etc/xdg"
               it 'should default unbound XDG_CONFIG_DIRS to default from XDG standard' do
                  default_xdg = Pathname.new('/etc/xdg')
                  ENV.delete('XDG_CONFIG_DIRS')

                  expect(locator.search_paths.length).to eq 1
                  expect(locator.search_paths.first).to eq default_xdg / namespace
               end
            end
         end

         describe '#find' do
            let(:locator) { described_class.new namespace }
            let(:filename) { 'some-file.yml' }
            let(:file_path) { Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / namespace / filename }

            context 'file is found' do
               before(:each) do
                  file_path.dirname.mkpath
                  file_path.write ''
               end

               it 'should return a path to the file' do
                  expect(locator.find(filename)).to eq file_path
               end
            end

            context 'file cannot be found' do
               it 'should explode' do
                  expect do
                     locator.find('bogus.yml')
                  end.to raise_error FileLocator::FileNotFoundError, 'Could not find bogus.yml'
               end
            end

            # This situation can be very confusing when you end up with multiple copies of the same file across
            # locations and you think you're editing the right one. The feature attempts to prevent that error.
            context 'multiple files are found' do
               let(:filename) { 'config.yml' }
               let(:path_a) { Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / namespace / filename }
               let(:path_b) { Pathname.new(XDG::Defaults::CONFIG_DIRS) / namespace / filename }

               before(:each) do
                  path_a.dirname.mkpath
                  path_b.dirname.mkpath

                  path_a.write 'file a'
                  path_b.write 'file b'
               end

               it 'should explode' do
                  expect { locator.find(filename) }.to raise_error AmbiguousSourceError
               end

               it 'should describe the problem' do
                  expect do
                     locator.find(filename)
                  end.to raise_error AmbiguousSourceError, include('Found more than 1 config.yml file')
               end

               it 'should list the places it found files' do
                  expect do
                     locator.find(filename)
                  end.to raise_error AmbiguousSourceError, include([path_a, path_b].join(', '))
               end
            end
         end
      end
   end
end
