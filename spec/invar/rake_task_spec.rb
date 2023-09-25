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
               allow_any_instance_of(Invar::Rake::Tasks::NamespacedFileTask).to receive(:system)
            end

            # Silencing the terminal output because there is a lot of it
            around(:each) do |example|
               $stdout = StringIO.new
               $stderr = StringIO.new
               example.run
               $stdout = STDOUT
               $stderr = STDERR
            end

            context 'invar:init' do
               let(:task) { ::Rake::Task['invar:init'] }

               it 'should define an init task' do
                  expect(::Rake::Task.task_defined?('invar:init')).to be true
               end

               context '$HOME is defined' do
                  let(:configs_dir) { Pathname.new(Invar::XDG::Defaults::CONFIG_HOME).expand_path / name }
                  let(:config_path) { configs_dir / 'config.yml' }
                  let(:secrets_path) { configs_dir / 'secrets.yml' }

                  it 'should create a config file in the XDG_CONFIG_HOME path' do
                     task.invoke

                     expect(config_path).to exist

                     file_mode = config_path.stat.mode & 0o777
                     expect(file_mode).to eq 0o600
                  end

                  it 'should create a secrets file in the XDG_CONFIG_HOME path' do
                     task.invoke

                     expect(secrets_path).to exist
                     file_mode = secrets_path.stat.mode & 0o777
                     expect(file_mode).to eq 0o600
                  end

                  it 'should only init config when specified' do
                     task.invoke('config')

                     expect(config_path).to exist
                     expect(secrets_path).to_not exist
                  end

                  it 'should only init secrets when specified' do
                     task.invoke('secrets')

                     expect(config_path).to_not exist
                     expect(secrets_path).to exist
                  end

                  it 'should declare the files it created' do
                     expected_output = include(config_path.to_s).and include(secrets_path.to_s)

                     expect { task.invoke }.to output(expected_output).to_stderr
                  end

                  it 'should encrypt the secrets file' do
                     allow(Lockbox).to receive(:generate_key).and_return default_lockbox_key

                     task.invoke

                     box = Lockbox.new(key: default_lockbox_key)

                     encrypted = secrets_path.binread

                     expect(box.decrypt(encrypted)).to eq Invar::Rake::Tasks::SECRETS_TEMPLATE
                  end

                  it 'should provide instructions for handling the secret' do
                     expect do
                        task.invoke
                     end.to output(include(Invar::Rake::Tasks::SecretsFileHandler::SECRETS_INSTRUCTIONS)).to_stderr
                  end

                  # this allows easier piping to a file or whatever
                  it 'should print the secret to stdout' do
                     allow(Lockbox).to receive(:generate_key).and_return default_lockbox_key

                     expect do
                        task.invoke
                     end.to output(include(default_lockbox_key)).to_stdout
                  end

                  context 'both files already exist' do
                     before do
                        configs_dir.mkpath
                        config_path.write ''
                        secrets_path.write ''
                     end

                     it 'should abort' do
                        msg = "Abort: Files already exist (#{ config_path }, #{ secrets_path })"
                        expect { task.invoke }.to output(include(msg)).to_stderr.and(raise_error(SystemExit))
                     end

                     it 'should suggest editing' do
                        suggestion = 'Maybe you meant to edit the file using rake tasks invar:config or invar:secrets?'
                        expect { task.invoke }.to output(include(suggestion)).to_stderr.and(raise_error(SystemExit))
                     end
                  end

                  context 'config file already exists' do
                     before do
                        configs_dir.mkpath
                        config_path.write ''
                     end

                     it 'should abort' do
                        msg = "Abort: Config file already exists (#{ config_path })"
                        expect { task.invoke }.to output(include(msg)).to_stderr.and(raise_error(SystemExit))
                     end

                     it 'should suggest using secrets parameter' do
                        cmd        = 'bundle exec rake tasks invar:init[secrets]'
                        suggestion = "Run this to init only the secrets file: #{ cmd }"
                        expect { task.invoke }.to output(include(suggestion)).to_stderr.and(raise_error(SystemExit))
                     end
                  end

                  context 'secrets file already exists' do
                     before do
                        configs_dir.mkpath
                        secrets_path.write ''
                     end

                     it 'should abort' do
                        msg = "Abort: Secrets file already exists (#{ secrets_path })"
                        expect { task.invoke }.to output(include(msg)).to_stderr.and(raise_error(SystemExit))
                     end

                     it 'should suggest using config parameter' do
                        suggestion = 'Run this to init only the config file: bundle exec rake tasks invar:init[config]'
                        expect { task.invoke }.to output(include(suggestion)).to_stderr.and(raise_error(SystemExit))
                     end
                  end
               end

               context '$HOME is undefined' do
                  let(:search_path) do
                     ENV.fetch('XDG_CONFIG_DIRS', Invar::XDG::Defaults::CONFIG_DIRS).split(':').collect do |p|
                        Pathname.new(p) / name
                     end
                  end
                  let(:configs_dir) { search_path.first }
                  let(:config_path) { configs_dir / 'config.yml' }
                  let(:secrets_path) { configs_dir / 'secrets.yml' }

                  around(:each) do |example|
                     old_home = Dir.home
                     ENV.delete('HOME')
                     example.run
                     ENV['HOME'] = old_home
                  end

                  it 'should create a config file in the first XDG_CONFIG_DIRS path' do
                     task.invoke

                     expect(config_path).to exist
                  end

                  it 'should create a secrets file in the first XDG_CONFIG_DIRS path' do
                     task.invoke

                     expect(secrets_path).to exist
                  end

                  it 'should declare the files it created' do
                     expected_output = include(config_path.to_s).and(include(secrets_path.to_s))
                     expect { task.invoke }.to output(expected_output).to_stderr
                  end

                  it 'should encrypt the secrets file' do
                     allow(Lockbox).to receive(:generate_key).and_return default_lockbox_key

                     task.invoke

                     box = Lockbox.new(key: default_lockbox_key)

                     encrypted = secrets_path.binread

                     expect(box.decrypt(encrypted)).to eq Invar::Rake::Tasks::SECRETS_TEMPLATE
                  end

                  it 'should provide instructions for handling the secret' do
                     expect do
                        task.invoke
                     end.to output(include(Invar::Rake::Tasks::SecretsFileHandler::SECRETS_INSTRUCTIONS)).to_stderr
                  end

                  # this allows easier piping to a file or whatever
                  it 'should print the decryption key to stdout' do
                     allow(Lockbox).to receive(:generate_key).and_return default_lockbox_key

                     expect do
                        task.invoke
                     end.to output(include(default_lockbox_key)).to_stdout
                  end

                  context 'both files already exist' do
                     before do
                        configs_dir.mkpath
                        config_path.write ''
                        secrets_path.write ''
                     end

                     it 'should abort' do
                        msg = "Abort: Files already exist (#{ config_path }, #{ secrets_path })"
                        expect { task.invoke }.to output(include(msg)).to_stderr.and(raise_error(SystemExit))
                     end

                     it 'should suggest editing' do
                        suggestion = 'Maybe you meant to edit the file using rake tasks invar:config or invar:secrets?'
                        expect { task.invoke }.to output(include(suggestion)).to_stderr.and(raise_error(SystemExit))
                     end
                  end

                  context 'config file already exists' do
                     before do
                        configs_dir.mkpath
                        config_path.write ''
                     end

                     it 'should abort' do
                        msg = "Abort: Config file already exists (#{ config_path })"
                        expect { task.invoke }.to output(include(msg)).to_stderr.and(raise_error(SystemExit))
                     end

                     it 'should suggest using secrets parameter' do
                        cmd        = 'bundle exec rake tasks invar:init[secrets]'
                        suggestion = "Run this to init only the secrets file: #{ cmd }"
                        expect { task.invoke }.to output(include(suggestion)).to_stderr.and(raise_error(SystemExit))
                     end
                  end

                  context 'secrets file already exists' do
                     before do
                        configs_dir.mkpath
                        secrets_path.write ''
                     end

                     it 'should abort' do
                        msg = "Abort: Secrets file already exists (#{ secrets_path })"
                        expect { task.invoke }.to output(include(msg)).to_stderr.and(raise_error(SystemExit))
                     end

                     it 'should suggest using config parameter' do
                        suggestion = 'Run this to init only the config file: bundle exec rake tasks invar:init[config]'
                        expect { task.invoke }.to output(include(suggestion)).to_stderr.and(raise_error(SystemExit))
                     end
                  end
               end
            end

            context 'invar:configs' do
               let(:task) { ::Rake::Task['invar:configs'] }

               it 'should define a configs edit task' do
                  expect(::Rake::Task.task_defined?('invar:configs')).to be true
               end

               it 'should alias config to configs' do
                  expect(::Rake::Task.task_defined?('invar:config')).to be true
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
                     expect_any_instance_of(Invar::Rake::Tasks::ConfigFileHandler)
                           .to receive(:system).with('editor', config_path.to_s, exception: true)

                     task.invoke
                  end

                  it 'should abort if the file does not exist' do
                     config_path.delete

                     xdg_home = ENV.fetch('XDG_CONFIG_HOME', Invar::XDG::Defaults::CONFIG_HOME)
                     xdg_dirs = ENV.fetch('XDG_CONFIG_DIRS', Invar::XDG::Defaults::CONFIG_DIRS).split(':')

                     search_path = [Pathname.new(xdg_home).expand_path / name]
                                         .concat(xdg_dirs.collect { |p| Pathname.new(p) / name })

                     msg = <<~MSG
                        Abort: Could not find #{ config_path.basename }. Searched in: #{ search_path.join(', ') }
                        #{ Invar::Rake::Tasks::CREATE_SUGGESTION }
                     MSG

                     expect { task.invoke }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end

                  it 'should state the file saved' do
                     config_path = configs_dir / 'config.yml'

                     expect { task.invoke }.to output(include(config_path.to_s)).to_stderr
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
                     expect_any_instance_of(Invar::Rake::Tasks::ConfigFileHandler)
                           .to receive(:system).with('editor', config_path.to_s, exception: true)

                     task.invoke
                  end

                  it 'should abort if the file does not exist' do
                     config_path.delete

                     msg = <<~MSG
                        Abort: Could not find #{ config_path.basename }. Searched in: #{ search_path.join(', ') }
                        #{ Invar::Rake::Tasks::CREATE_SUGGESTION }
                     MSG

                     expect { task.invoke }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end

                  it 'should state the file saved' do
                     expect { task.invoke }.to output(include(config_path.to_s)).to_stderr
                  end
               end

               context 'content provided in stdin' do
                  let(:configs_dir) { Pathname.new(Invar::XDG::Defaults::CONFIG_HOME).expand_path / name }
                  let(:config_path) { configs_dir / 'config.yml' }

                  before(:each) do
                     configs_dir.mkpath
                     config_path.write ''
                  end

                  let(:input_string) do
                     <<~YML
                        ---
                        breakfast: 'second'
                     YML
                  end
                  let(:input) do
                     StringIO.new input_string
                  end

                  around(:each) do |example|
                     $stdin = input
                     example.run
                     $stdin = STDIN
                  end

                  it 'should not open the editor' do
                     expect_any_instance_of(Invar::Rake::Tasks::ConfigFileHandler)
                           .to_not receive(:system).with('editor')

                     task.invoke
                  end

                  it 'should use the provided content' do
                     task.invoke

                     expect(config_path.read).to eq input_string
                  end
               end
            end

            context 'invar:secrets' do
               let(:task) { ::Rake::Task['invar:secrets'] }

               before(:each) do
                  # Prevent it from opening actual editor
                  allow(Invar::Rake::Tasks).to receive(:system)
               end

               it 'should define a secrets edit task' do
                  expect(::Rake::Task.task_defined?('invar:secrets')).to be true
               end

               it 'should alias secret to secrets' do
                  expect(::Rake::Task.task_defined?('invar:secret')).to be true
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
                     secrets_path.chmod(0o600)
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
                           $stdin = double('fake IO', noecho: default_lockbox_key, tty?: true)
                           task.invoke
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
                              $stdin = double('fake IO', noecho: default_lockbox_key, tty?: true)
                              task.invoke
                              $stdin = STDIN
                           end.to output(start_with(msg)).to_stderr
                        end

                        it 'should read the password from STDIN without echo' do
                           input = double('fake input', tty?: true)

                           $stdin = input

                           expect(input).to receive(:noecho).and_return default_lockbox_key

                           task.invoke

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
                              task.invoke
                           end.to(raise_error(Invar::SecretsFileEncryptionError).and(output('').to_stderr))
                        end
                     end
                  end

                  it 'should abort if the file does not exist' do
                     secrets_path.delete

                     xdg_home = ENV.fetch('XDG_CONFIG_HOME', Invar::XDG::Defaults::CONFIG_HOME)
                     xdg_dirs = ENV.fetch('XDG_CONFIG_DIRS', Invar::XDG::Defaults::CONFIG_DIRS).split(':')

                     search_path = [Pathname.new(xdg_home).expand_path / name]
                                         .concat(xdg_dirs.collect { |p| Pathname.new(p) / name })

                     msg = <<~MSG
                        Abort: Could not find #{ secrets_path.basename }. Searched in: #{ search_path.join(', ') }
                        #{ Invar::Rake::Tasks::CREATE_SUGGESTION }
                     MSG

                     expect { task.invoke }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end

                  it 'should state the file saved' do
                     Lockbox.master_key = default_lockbox_key

                     expect { task.invoke }.to output(include(secrets_path.to_s)).to_stderr
                  end

                  it 'should clone the decrypted contents into the tempfile' do
                     Lockbox.master_key = default_lockbox_key
                     new_content        = '---'
                     tmpfile            = double('tmpfile', path: '/tmp/whatever', read: new_content)

                     allow(Tempfile).to receive(:create).and_yield(tmpfile).and_return new_content

                     expect(tmpfile).to receive(:write).with("---\n")
                     expect(tmpfile).to receive(:rewind)

                     task.invoke
                  end

                  it 'should edit the secrets tmpfile' do
                     Lockbox.master_key = default_lockbox_key
                     tmpfile            = double('tmpfile', write: nil, rewind: nil, read: '---', path: '/tmp/whatever')

                     allow(Tempfile).to receive(:create).and_yield(tmpfile).and_return '---'

                     # the intention of 'exception: true' is to noisily fail, which can be useful when automating
                     expect_any_instance_of(Invar::Rake::Tasks::SecretsFileHandler)
                           .to receive(:system).with('editor', '/tmp/whatever', exception: true)

                     task.invoke
                  end

                  it 'should update the encrypted file with new contents' do
                     Lockbox.master_key = default_lockbox_key

                     new_contents = <<~YML
                        ---
                        password: mellon
                     YML
                     tmpfile = double('tmpfile', path: '/tmp/whatever', write: nil, rewind: nil, read: new_contents)
                     allow(Tempfile).to receive(:create).and_yield tmpfile

                     task.invoke

                     lockbox = Lockbox.new(key: default_lockbox_key)

                     expect(lockbox.decrypt(secrets_path.read)).to eq new_contents
                  end

                  it 'should not try to change the permissions' do
                     custom_permissions = 0o640
                     secrets_path.chmod custom_permissions

                     Lockbox.master_key = default_lockbox_key

                     new_contents = <<~YML
                        ---
                        password: mellon
                     YML
                     tmpfile = double('tmpfile', path: '/tmp/whatever', write: nil, rewind: nil, read: new_contents)
                     allow(Tempfile).to receive(:create).and_yield tmpfile

                     task.invoke

                     lockbox = Lockbox.new(key: default_lockbox_key)

                     expect(lockbox.decrypt(secrets_path.read)).to eq new_contents
                     mode = secrets_path.lstat.mode & PrivateFile::PERMISSIONS_MASK
                     expect(mode).to eq custom_permissions
                  end

                  context 'content provided in stdin' do
                     let(:input_string) do
                        <<~YML
                           ---
                           password: 'mellon'
                        YML
                     end
                     let(:input) do
                        StringIO.new input_string
                     end

                     around(:each) do |example|
                        $stdin = input
                        example.run
                        $stdin = STDIN
                     end

                     it 'should not open the editor' do
                        expect_any_instance_of(Invar::Rake::Tasks::SecretsFileHandler)
                              .to_not receive(:system).with('editor')

                        task.invoke
                     end

                     it 'should use the provided content' do
                        Lockbox.master_key = default_lockbox_key

                        task.invoke

                        lockbox = Lockbox.new(key: default_lockbox_key)
                        expect(lockbox.decrypt(secrets_path.read)).to eq input_string
                     end
                  end
               end
            end

            context 'invar:rotate' do
               let(:task) { ::Rake::Task['invar:rotate'] }

               before(:each) do
                  # Prevent it from opening actual editor
                  allow(Invar::Rake::Tasks).to receive(:system)
               end

               it 'should define a key rotation task' do
                  expect(::Rake::Task.task_defined?('invar:rotate')).to be true
               end

               context '$HOME is defined' do
                  let(:home) { '/some/home/dir' }
                  let(:configs_dir) { Pathname.new(Invar::XDG::Defaults::CONFIG_HOME).expand_path / name }
                  let(:secrets_path) { configs_dir / 'secrets.yml' }
                  let(:secrets_content) do
                     <<~YML
                        ---
                        password: mellon
                     YML
                  end

                  around(:each) do |example|
                     old_home    = Dir.home
                     ENV['HOME'] = home.to_s
                     example.run
                     ENV['HOME'] = old_home
                  end

                  before(:each) do
                     configs_dir.mkpath
                     lockbox = Lockbox.new(key: default_lockbox_key)

                     secrets_path.write lockbox.encrypt(secrets_content)
                     secrets_path.chmod 0o600
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
                           task.invoke
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
                              task.invoke
                              $stdin = STDIN
                           end.to output(start_with(msg)).to_stderr
                        end

                        it 'should read the password from STDIN without echo' do
                           input = double('fake input')

                           $stdin = input

                           expect(input).to receive(:noecho).and_return default_lockbox_key

                           task.invoke

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
                              task.invoke
                           end.to(raise_error(Invar::SecretsFileEncryptionError).and(output('').to_stderr))
                        end
                     end
                  end

                  it 'should abort if the file does not exist' do
                     secrets_path.delete

                     xdg_home = ENV.fetch('XDG_CONFIG_HOME', Invar::XDG::Defaults::CONFIG_HOME)
                     xdg_dirs = ENV.fetch('XDG_CONFIG_DIRS', Invar::XDG::Defaults::CONFIG_DIRS).split(':')

                     search_path = [Pathname.new(xdg_home).expand_path / name]
                                         .concat(xdg_dirs.collect { |p| Pathname.new(p) / name })

                     msg = <<~MSG
                        Abort: Could not find #{ secrets_path.basename }. Searched in: #{ search_path.join(', ') }
                        #{ Invar::Rake::Tasks::CREATE_SUGGESTION }
                     MSG

                     expect { task.invoke }.to output(msg).to_stderr.and(raise_error(SystemExit))
                  end

                  let(:new_key) do
                     $stdout.rewind
                     $stdout.readline.chomp
                  end

                  it 'should re-encrypt the file under the new key' do
                     Lockbox.master_key = default_lockbox_key

                     task.invoke

                     lockbox = Lockbox.new(key: new_key)

                     expect(lockbox.decrypt(secrets_path.read)).to eq secrets_content
                  end

                  it 'should clean up the swap file' do
                     Lockbox.master_key = default_lockbox_key

                     task.invoke

                     expect(File).to_not exist("#{ secrets_path }.#{ Tasks::SecretsFileHandler::SWAP_EXT }")
                  end

                  it 'should return the swap file when aborting' do
                     Lockbox.master_key = default_lockbox_key

                     secrets_path.chmod 0o400 # read-only
                     allow(File).to receive(:open) do
                        raise Errno::ENOSPC, 'Dummy write failure'
                     end
                     task.invoke

                     expect(File).to_not exist("#{ secrets_path }.#{ Tasks::SecretsFileHandler::SWAP_EXT }")
                     expect(File).to exist(secrets_path)

                     lockbox = Lockbox.new(key: default_lockbox_key)
                     expect(lockbox.decrypt(secrets_path.read)).to eq secrets_content
                  end

                  it 'should state the updated file' do
                     Lockbox.master_key = default_lockbox_key

                     expect { task.invoke }.to output(include(secrets_path.to_s)).to_stderr
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
                     task.invoke
                  end.to output(expected_stderr).to_stderr
               end
            end
         end
      end
   end
end
