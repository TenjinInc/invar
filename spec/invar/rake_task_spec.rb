# frozen_string_literal: true

require 'spec_helper'

# Intentionally kept separate from main lib require so that folks can use the rake tasks optionally
require 'invar/rake/tasks'

module Invar
   module Rake
      describe Tasks do
         let(:name) { 'test-app' }
         let(:default_lockbox_key) { '0000000000000000000000000000000000000000000000000000000000000000' }

         context '.define' do
            it 'should create an instance and call #define on it' do
               instance = double('tasks instance')
               expect(described_class).to receive(:new).and_return instance

               expect(instance).to receive(:define)

               described_class.define(namespace: name)
            end
         end

         describe '#define' do
            it 'should explode if the namespace argument is nil' do
               msg = ':namespace keyword argument cannot be nil'
               expect { described_class.define namespace: nil }.to raise_error ArgumentError, include(msg)
            end

            it 'should explode if the namespace argument is empty string' do
               msg = ':namespace keyword argument cannot be empty string'
               expect { described_class.define namespace: '' }.to raise_error ArgumentError, include(msg)
            end
         end

         describe 'Task Implementation' do
            before(:each) do
               ::Rake::Task.clear
               described_class.define namespace: name

               task.reenable

               # Prevent it from opening actual editor
               allow_any_instance_of(Invar::Rake::Tasks::NamespacedTask).to receive(:system)
            end

            # Silencing the terminal output because there is a lot of it
            around(:each) do |example|
               $stdout = StringIO.new
               $stderr = StringIO.new
               example.run
               $stdout = STDOUT
               $stderr = STDERR
            end

            context 'invar:configs:create' do
               let(:task) { ::Rake::Task['invar:configs:create'] }

               it 'should define a configs create task' do
                  expect(::Rake::Task.task_defined?('invar:configs:create')).to be true
               end

               it 'should alias config:create' do
                  expect(::Rake::Task.task_defined?('invar:config:create')).to be true
               end

               context '$HOME is defined' do
                  let(:configs_dir) { Pathname.new(Invar::XDG::Defaults::CONFIG_HOME).expand_path / name }
                  let(:config_path) { configs_dir / 'config.yml' }

                  it 'should create a config file in the XDG_CONFIG_HOME path' do
                     task.invoke(name)

                     expect(config_path).to exist
                  end

                  it 'should state the file it created' do
                     expect { task.invoke(name) }.to output(include(config_path.to_s)).to_stderr
                  end

                  it 'should abort if the file already exists' do
                     configs_dir.mkpath
                     config_path.write ''

                     msg = <<~MSG
                        Abort: File exists. (#{ config_path })
                        Maybe you meant to edit the file with bundle exec rake invar:secrets:edit?
                     MSG
                     expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end
               end

               context '$HOME is undefined' do
                  let(:configs_dir) do
                     xdg_default = Invar::XDG::Defaults::CONFIG_DIRS
                     Pathname.new(ENV.fetch('XDG_CONFIG_DIRS', xdg_default).split(':').first).expand_path / name
                  end
                  let(:config_path) { configs_dir / 'config.yml' }

                  around(:each) do |example|
                     old_home = Dir.home
                     ENV.delete('HOME')
                     example.run
                     ENV['HOME'] = old_home
                  end

                  it 'should create a config file in the first XDG_CONFIG_DIRS path' do
                     task.invoke(name)

                     expect(config_path).to exist
                  end

                  it 'should state the file it created' do
                     expect { task.invoke(name) }.to output(include(config_path.to_s)).to_stderr
                  end
               end
            end

            context 'invar:configs:edit' do
               let(:task) { ::Rake::Task['invar:configs:edit'] }

               it 'should define a configs edit task' do
                  expect(::Rake::Task.task_defined?('invar:configs:edit')).to be true
               end

               it 'should alias config:create' do
                  expect(::Rake::Task.task_defined?('invar:config:edit')).to be true
               end

               context '$HOME is defined' do
                  let(:configs_dir) { Pathname.new(Invar::XDG::Defaults::CONFIG_HOME).expand_path / name }
                  let(:config_path) { configs_dir / 'config.yml' }

                  before(:each) do
                     configs_dir.mkpath
                     config_path.write ''
                  end

                  it 'should edit the config file in the XDG_CONFIG_HOME path' do
                     # the intention of 'exception: true' is to noisily fail, which can be useful when automating
                     expect_any_instance_of(Invar::Rake::Tasks::ConfigTask).to receive(:system).with('editor', config_path.to_s, exception: true)

                     task.invoke(name)
                  end

                  it 'should abort if the file does not exist' do
                     config_path.delete

                     xdg_home = ENV.fetch('XDG_CONFIG_HOME', Invar::XDG::Defaults::CONFIG_HOME)
                     xdg_dirs = ENV.fetch('XDG_CONFIG_DIRS', Invar::XDG::Defaults::CONFIG_DIRS).split(':')

                     search_path = [Pathname.new(xdg_home).expand_path / name].concat(xdg_dirs.collect { |p| Pathname.new(p) / name })

                     msg = <<~MSG
                        Abort: Could not find #{ config_path.basename }. Searched in: #{ search_path.join(', ') }
                        Maybe you used the wrong namespace or need to create the file with bundle exec rake invar:configs:create?
                     MSG

                     expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end

                  it 'should state the file saved' do
                     config_path = configs_dir / 'config.yml'

                     expect { task.invoke(name) }.to output(include(config_path.to_s)).to_stderr
                  end
               end

               context '$HOME is undefined' do
                  let(:search_path) do
                     ENV.fetch('XDG_CONFIG_DIRS', Invar::XDG::Defaults::CONFIG_DIRS).split(':').collect do |p|
                        Pathname.new(p) / name
                     end
                  end
                  let(:config_path) { search_path.first / 'config.yml' }

                  before(:each) do
                     search_path.each(&:mkpath)
                     config_path.write ''
                  end

                  around(:each) do |example|
                     old_home = Dir.home
                     ENV.delete('HOME')
                     example.run
                     ENV['HOME'] = old_home
                  end

                  it 'should edit the config file in the first XDG_CONFIG_DIRS path' do
                     # the intention of 'exception: true' is to noisily fail, which can be useful when automating
                     expect_any_instance_of(Invar::Rake::Tasks::ConfigTask).to receive(:system).with('editor', config_path.to_s, exception: true)

                     task.invoke(name)
                  end

                  it 'should abort if the file does not exist' do
                     config_path.delete

                     msg = <<~MSG
                        Abort: Could not find #{ config_path.basename }. Searched in: #{ search_path.join(', ') }
                        Maybe you used the wrong namespace or need to create the file with bundle exec rake invar:configs:create?
                     MSG

                     expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end

                  it 'should state the file saved' do
                     expect { task.invoke(name) }.to output(include(config_path.to_s)).to_stderr
                  end
               end
            end

            context 'invar:secrets:create' do
               let(:task) { ::Rake::Task['invar:secrets:create'] }

               it 'should define a secrets create task' do
                  expect(::Rake::Task.task_defined?('invar:secrets:create')).to be true
               end

               it 'should alias secret:create' do
                  expect(::Rake::Task.task_defined?('invar:secret:create')).to be true
               end

               context '$HOME is defined' do
                  let(:configs_dir) { Pathname.new(Invar::XDG::Defaults::CONFIG_HOME).expand_path / name }
                  let(:secrets_path) { configs_dir / 'secrets.yml' }

                  it 'should create a secrets file in the XDG_CONFIG_HOME path' do
                     task.invoke(name)

                     expect(secrets_path).to exist
                  end

                  it 'should encrypt the secrets file' do
                     allow(Lockbox).to receive(:generate_key).and_return default_lockbox_key

                     task.invoke(name)

                     box = Lockbox.new(key: default_lockbox_key)

                     encrypted = secrets_path.binread

                     expect(box.decrypt(encrypted)).to eq Invar::Rake::Tasks::SECRETS_TEMPLATE
                  end

                  it 'should provide instructions for handling the secret' do
                     expect do
                        task.invoke(name)
                     end.to output(include(Invar::Rake::Tasks::SecretTask::SECRETS_INSTRUCTIONS)).to_stderr
                  end

                  # this allows easier piping to a file or whatever
                  it 'should print the secret to stdout' do
                     allow(Lockbox).to receive(:generate_key).and_return default_lockbox_key

                     expect do
                        task.invoke(name)
                     end.to output(include(default_lockbox_key)).to_stdout
                  end

                  it 'should state the file it created' do
                     expect { task.invoke(name) }.to output(include(secrets_path.to_s)).to_stderr
                  end

                  it 'should abort if the file already exists' do
                     configs_dir.mkpath
                     secrets_path.write ''

                     msg = <<~MSG
                        Abort: File exists. (#{ secrets_path })
                        Maybe you meant to edit the file with bundle exec rake invar:secrets:edit?
                     MSG
                     expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end
               end

               context '$HOME is undefined' do
                  let(:search_path) do
                     ENV.fetch('XDG_CONFIG_DIRS', Invar::XDG::Defaults::CONFIG_DIRS).split(':').collect do |p|
                        Pathname.new(p) / name
                     end
                  end
                  let(:configs_dir) { search_path.first }
                  let(:secrets_path) { configs_dir / 'secrets.yml' }

                  around(:each) do |example|
                     old_home = Dir.home
                     ENV.delete('HOME')
                     example.run
                     ENV['HOME'] = old_home
                  end

                  it 'should create a secrets file in the first XDG_CONFIG_DIRS path' do
                     task.invoke(name)

                     expect(secrets_path).to exist
                  end

                  it 'should encrypt the secrets file' do
                     allow(Lockbox).to receive(:generate_key).and_return default_lockbox_key

                     task.invoke(name)

                     box = Lockbox.new(key: default_lockbox_key)

                     encrypted = secrets_path.binread

                     expect(box.decrypt(encrypted)).to eq Invar::Rake::Tasks::SECRETS_TEMPLATE
                  end

                  it 'should provide instructions for handling the secret' do
                     expect do
                        task.invoke(name)
                     end.to output(include(Invar::Rake::Tasks::SecretTask::SECRETS_INSTRUCTIONS)).to_stderr
                  end

                  # this allows easier piping to a file or whatever
                  it 'should print the secret to stdout' do
                     allow(Lockbox).to receive(:generate_key).and_return default_lockbox_key

                     expect do
                        task.invoke(name)
                     end.to output(include(default_lockbox_key)).to_stdout
                  end

                  it 'should state the file it created' do
                     expect { task.invoke(name) }.to output(include(secrets_path.to_s)).to_stderr
                  end

                  it 'should abort if the file already exists' do
                     configs_dir.mkpath
                     secrets_path.write ''

                     msg = <<~MSG
                        Abort: File exists. (#{ secrets_path })
                        Maybe you meant to edit the file with bundle exec rake invar:secrets:edit?
                     MSG
                     expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end
               end
            end

            context 'invar:secrets:edit' do
               let(:task) { ::Rake::Task['invar:secrets:edit'] }

               before(:each) do
                  # Prevent it from opening actual editor
                  allow(Invar::Rake::Tasks).to receive(:system)
               end

               it 'should define a secrets edit task' do
                  expect(::Rake::Task.task_defined?('invar:secrets:edit')).to be true
               end

               it 'should alias secret:edit' do
                  expect(::Rake::Task.task_defined?('invar:secret:edit')).to be true
               end

               context '$HOME is defined' do
                  let(:home) { '/some/home/dir' }
                  let(:configs_dir) { Pathname.new(Invar::XDG::Defaults::CONFIG_HOME).expand_path / name }
                  let(:secrets_path) { configs_dir / 'secrets.yml' }

                  around(:each) do |example|
                     old_home    = Dir.home
                     ENV['HOME'] = home.to_s
                     example.run
                     ENV['HOME'] = old_home
                  end

                  before(:each) do
                     configs_dir.mkpath
                     lockbox = Lockbox.new(key: default_lockbox_key)

                     secrets_path.write lockbox.encrypt <<~YML
                        ---
                     YML
                  end

                  context 'Lockbox master key is defined' do
                     before(:each) do
                        Lockbox.master_key = default_lockbox_key
                     end

                     around(:each) do |example|
                        old_key            = Lockbox.master_key
                        Lockbox.master_key = default_lockbox_key
                        example.run
                        Lockbox.master_key = old_key
                     end

                     it 'should NOT ask for it from STDIN' do
                        msg = 'Enter master key to decrypt'

                        expect do
                           $stdin = double('fake IO', noecho: default_lockbox_key)
                           task.invoke(name)
                           $stdin = STDIN
                        end.to_not output(include(msg)).to_stderr
                     end
                  end

                  context 'Lockbox master key is undefined' do
                     around(:each) do |example|
                        old_key            = Lockbox.master_key
                        Lockbox.master_key = nil
                        example.run
                        Lockbox.master_key = old_key
                     end

                     context 'STDIN can #noecho' do
                        it 'should ask for it from STDIN' do
                           msg = "Enter master key to decrypt #{ secrets_path }:"

                           expect do
                              $stdin = double('fake IO', noecho: default_lockbox_key)
                              task.invoke(name)
                              $stdin = STDIN
                           end.to output(start_with(msg)).to_stderr
                        end

                        it 'should read the password from STDIN without echo' do
                           input = double('fake input')

                           $stdin = input

                           expect(input).to receive(:noecho).and_return default_lockbox_key

                           task.invoke(name)

                           $stdin = STDIN
                        end
                     end

                     context 'STDIN cannot #noecho' do
                        let(:input) { StringIO.new }

                        around(:each) do |example|
                           $stdin = input
                           example.run
                           $stdin = STDIN
                        end

                        it 'should raise an error instead of asking from STDIN' do
                           expect do
                              task.invoke(name)
                           end.to(raise_error(Invar::SecretsFileEncryptionError).and(output('').to_stderr))
                        end
                     end
                  end

                  it 'should abort if the file does not exist' do
                     secrets_path.delete

                     xdg_home = ENV.fetch('XDG_CONFIG_HOME', Invar::XDG::Defaults::CONFIG_HOME)
                     xdg_dirs = ENV.fetch('XDG_CONFIG_DIRS', Invar::XDG::Defaults::CONFIG_DIRS).split(':')

                     search_path = [Pathname.new(xdg_home).expand_path / name].concat(xdg_dirs.collect { |p| Pathname.new(p) / name })

                     msg = <<~MSG
                        Abort: Could not find #{ secrets_path.basename }. Searched in: #{ search_path.join(', ') }
                        Maybe you used the wrong namespace or need to create the file with bundle exec rake invar:secrets:create?
                     MSG

                     expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end

                  it 'should clone the decrypted contents into the tempfile' do
                     Lockbox.master_key = default_lockbox_key
                     new_content        = '---'
                     tmpfile            = double('tmpfile', path: '/tmp/whatever', read: new_content)

                     allow(Tempfile).to receive(:create).and_yield(tmpfile).and_return new_content

                     expect(tmpfile).to receive(:write).with("---\n")
                     expect(tmpfile).to receive(:rewind)

                     task.invoke(name)
                  end

                  it 'should edit the secrets tmpfile' do
                     Lockbox.master_key = default_lockbox_key
                     tmpfile            = double('tmpfile', write: nil, rewind: nil, read: '---', path: '/tmp/whatever')

                     allow(Tempfile).to receive(:create).and_yield(tmpfile).and_return '---'

                     # the intention of 'exception: true' is to noisily fail, which can be useful when automating
                     expect_any_instance_of(Invar::Rake::Tasks::SecretTask).to receive(:system).with('editor', '/tmp/whatever', exception: true)

                     task.invoke(name)
                  end

                  it 'should update the encrypted file with new contents' do
                     Lockbox.master_key = default_lockbox_key

                     new_contents = <<~YML
                        ---
                        password: mellon
                     YML
                     tmpfile = double('tmpfile', path: '/tmp/whatever', write: nil, rewind: nil, read: new_contents)
                     allow(Tempfile).to receive(:create).and_yield tmpfile

                     task.invoke(name)

                     lockbox = Lockbox.new(key: default_lockbox_key)

                     expect(lockbox.decrypt(secrets_path.read)).to eq new_contents
                  end

                  it 'should state the file saved' do
                     Lockbox.master_key = default_lockbox_key

                     expect { task.invoke(name) }.to output(include(secrets_path.to_s)).to_stderr
                  end
               end
            end

            context 'invar:paths' do
               let(:task) { ::Rake::Task['invar:paths'] }

               it 'should report the search paths' do
                  xdg_config_home = ENV.fetch('XDG_CONFIG_HOME', ::Invar::XDG::Defaults::CONFIG_HOME)
                  xdg_config_dirs = ENV.fetch('XDG_CONFIG_DIRS', ::Invar::XDG::Defaults::CONFIG_DIRS).split(':')

                  xdg_config_home_path  = Pathname.new(xdg_config_home).expand_path / name
                  xdg_config_dirs_paths = xdg_config_dirs.collect { |p| Pathname.new(p) / name }

                  expected_stderr = <<~ERR
                     #{ xdg_config_home_path }
                     #{ xdg_config_dirs_paths.join("\n") }
                  ERR

                  expect do
                     task.invoke(name)
                  end.to output(expected_stderr).to_stderr
               end
            end
         end
      end
   end
end
