# frozen_string_literal: true

require 'spec_helper'

module Dirt
   describe Envelope do
      it 'should have a version number' do
         expect(Dirt::Envelope::VERSION).not_to be nil
      end
   end

   module Envelope
      describe Envelope do
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

         describe '#initialize' do
            let(:default_yaml) do
               <<~YML
                  ---
               YML
            end

            it 'should explode when namespace missing' do
               expect { described_class.new }.to raise_error ArgumentError, 'missing keyword: :namespace'
            end

            it 'should explode when provided an empty namespace' do
               expect do
                  described_class.new namespace: ''
               end.to raise_error InvalidAppNameError, ':namespace cannot be an empty string'
            end

            it 'should explode when provided a nil namespace' do
               expect do
                  described_class.new namespace: nil
               end.to raise_error InvalidAppNameError, ':namespace cannot be nil'
            end

            # Immutability enables safe use in multithreaded situations (like a webserver)
            # and just general state & behaviour predictability.
            # It does not, however, guarantee the actual stored values are also frozen.
            it 'should freeze the ENVelope after creation' do
               config_path = Pathname.new('~/.config/test-app/config.yml').expand_path
               config_path.dirname.mkpath
               config_path.write default_yaml

               envelope = described_class.new namespace: 'test-app'

               expect(envelope).to be_frozen
            end

            context 'config file missing' do
               it 'should explode' do
                  expect do
                     described_class.new namespace: 'my-app'
                  end.to raise_error MissingConfigFileError, start_with('No config file found.')
               end

               it 'should hint at a solution' do
                  msg = 'Create config.yml in one of these locations'

                  expect do
                     described_class.new namespace: 'my-app'
                  end.to raise_error MissingConfigFileError, include(msg)
               end

               it 'should state the locations searched' do
                  # TODO: this will need to be the full XDG pathset
                  home_dir  = Pathname.new('~').expand_path
                  path_list = [home_dir / '.config/my-app']

                  expect do
                     described_class.new namespace: 'my-app'
                  end.to raise_error MissingConfigFileError, include(path_list.join(', '))
               end
            end

            context '$HOME is defined' do
               let(:home) { Pathname.new '/some/home/path' }
               let(:name) { 'test-app' }

               around(:each) do |example|
                  # store original values
                  old_home = Dir.home

                  # actual test setup
                  ENV['HOME'] = home.to_s
                  example.run

                  # reset original values
                  ENV['HOME'] = old_home
               end

               it 'should search for config in XDG_CONFIG_HOME' do
                  config_root            = Pathname.new 'an_alternate/home-config/path'
                  ENV['XDG_CONFIG_HOME'] = config_root.to_s
                  config_path            = config_root / 'test-app/config.yml'
                  config_path.dirname.mkpath
                  config_path.write default_yaml

                  described_class.new namespace: name
               end

               # Standard defines default as "$HOME/.config"
               it 'should default unbound XDG_CONFIG_HOME to default from XDG standard' do
                  ENV.delete('XDG_CONFIG_HOME')
                  config_path = home / '.config' / 'test-app/config.yml'
                  config_path.dirname.mkpath
                  config_path.write default_yaml

                  described_class.new namespace: name
               end

               it 'should search in the given namespace' do
                  ENV['XDG_CONFIG_HOME'] = '/somewhere'

                  %w[some-app another-app].each do |name|
                     config_path = Pathname.new('/somewhere') / name / 'config.yml'
                     config_path.dirname.mkpath
                     config_path.write default_yaml

                     described_class.new namespace: name
                  end
               end
            end

            context '$HOME is undefined' do
               let(:name) { 'test-app' }

               around(:each) do |example|
                  # store original values
                  old_home = Dir.home

                  # actual test setup
                  ENV.delete('HOME')
                  example.run

                  # reset original values
                  ENV['HOME'] = old_home
               end

               # Config dirs are a priority list and colon-separated
               it 'should find a config in any XDG_CONFIG_DIRS directory' do
                  config_dirs            = 'an_alternate/home:config/path'
                  ENV['XDG_CONFIG_DIRS'] = config_dirs.to_s

                  config_dirs.split(':').each do |path|
                     config_path = Pathname.new(path) / 'test-app/config.yml'
                     config_path.dirname.mkpath
                     config_path.write default_yaml

                     described_class.new namespace: name
                     config_path.delete # delete to clear for other test
                  end
               end

               # Standard defines default as "/etc/xdg"
               it 'should default unbound XDG_CONFIG_DIRS to default from XDG standard' do
                  ENV.delete('XDG_CONFIG_DIRS')
                  config_path = Pathname.new('/etc/xdg') / 'test-app/config.yml'
                  config_path.dirname.mkpath
                  config_path.write default_yaml

                  described_class.new namespace: name
               end

               it 'should search in the given namespace' do
                  ENV['XDG_CONFIG_DIRS'] = '/somewhere'

                  %w[some-app another-app].each do |name|
                     config_path = Pathname.new('/somewhere') / name / 'config.yml'
                     config_path.dirname.mkpath
                     config_path.write default_yaml

                     described_class.new namespace: name
                  end
               end
            end

            # This can be an error and very confusing when you end up with multiple copies of the same file across
            # locations and you think you're editing the right one. The feature attempts to prevent that error.
            context 'multiple config files are found' do
               let(:name) { 'test-app' }
               let(:path_a) { Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name / 'config.yml' }
               let(:path_b) { Pathname.new(XDG::Defaults::CONFIG_DIRS) / name / 'config.yml' }

               before(:each) do
                  path_a.dirname.mkpath
                  path_b.dirname.mkpath

                  path_a.write default_yaml
                  path_b.write default_yaml
               end

               it 'should explode' do
                  expect { described_class.new namespace: name }.to raise_error AmbiguousSourceError
               end

               it 'should describe the problem' do
                  expect do
                     described_class.new namespace: name
                  end.to raise_error AmbiguousSourceError, include('Found more than 1 config file')
               end

               it 'should list the places it found files' do
                  expect do
                     described_class.new namespace: name
                  end.to raise_error AmbiguousSourceError, include([path_a, path_b].join(', '))
               end
            end
         end

         # Slash operator
         describe '#/' do
            let(:path) { Pathname.new('~/.config/test-app/config.yml').expand_path }
            let(:envelope) { described_class.new namespace: 'test-app' }

            before(:each) do
               path.dirname.mkpath
               path.write <<~YML
                  ---
                  domain: example.com
                  database: 
                     name: 'test_db'
                     host: 'localhost'
                  party:
                     name: 'Birthday'
                     host: 'Bilbo Baggins'
               YML
            end

            it 'should fetch values with a symbol' do
               expect(envelope / :domain).to eq 'example.com'
            end

            it 'should fetch values with a string' do
               expect(envelope / 'domain').to eq 'example.com'
            end

            it 'should scope into subsections with a symbol' do
               expect(envelope / :database / :host).to eq 'localhost'
            end

            it 'should scope into subsections with a string' do
               expect(envelope / 'database' / 'host').to eq 'localhost'
            end
         end
      end
   end
end
