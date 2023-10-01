# frozen_string_literal: true

require 'spec_helper'

module Invar
   describe Reality do
      let(:name) { 'my-app' }
      let(:default_lockbox_key) { '0' * 64 }
      let(:lockbox) { Lockbox.new(key: default_lockbox_key) }
      let(:clear_yaml) do
         <<~YML
            ---
         YML
      end

      let(:configs_dir) { Pathname.new('~/.config').expand_path / name }
      let(:config_path) { configs_dir / 'config.yml' }
      let(:secrets_path) { configs_dir / 'secrets.yml' }
      let(:key_path) { configs_dir / 'master_key' }

      before :each do
         gem_dir = Pathname.new(ENV.fetch('GEM_HOME')) / 'gems'

         dry_gems = Bundler.locked_gems.specs.collect(&:full_name).select do |name|
            name.start_with? 'dry-schema', 'dry-logic'
         end

         # need to clone dry gems because they seem to lazy load after FakeFS is engaged
         # TODO: this will disappear if FakeFS is removed
         dry_gems.each do |path|
            FakeFS::FileSystem.clone(gem_dir / path)
         end
      end

      before(:each) do
         configs_dir.mkpath

         config_path.write '---'
         config_path.chmod 0o600
         secrets_path.write lockbox.encrypt('---')
         config_path.chmod 0o600

         key_path.write default_lockbox_key
         key_path.chmod 0o600
      end

      describe '#initialize' do
         let(:configs_dir) { Pathname.new('~/.config').expand_path / name }
         let(:config_path) { configs_dir / 'config.yml' }
         let(:secrets_path) { configs_dir / 'secrets.yml' }

         it 'should explode when namespace missing' do
            expect { described_class.new }.to raise_error ArgumentError, 'missing keyword: :namespace'
         end

         # Immutability enables safe use in multithreaded situations (like a webserver)
         # and just general state & behaviour predictability.
         # It does not, however, guarantee the actual stored values are also frozen.
         it 'should freeze the Invar after creation' do
            configs_dir.mkpath

            config_path.write clear_yaml
            config_path.chmod 0o600
            secrets_path.write lockbox.encrypt clear_yaml
            secrets_path.chmod 0o600

            key_file = configs_dir / 'master_key'
            key_file.write default_lockbox_key
            key_file.chmod 0o600

            invar = described_class.new namespace: name

            expect(invar).to be_frozen
         end

         context 'schema' do
            let(:configs_schema) do
               Dry::Schema.define do
                  required(:database).schema do
                     required(:name).filled
                  end
               end
            end

            let(:secrets_schema) do
               Dry::Schema.define do
                  required(:database).hash do
                     required(:password).filled
                  end
               end
            end

            before(:each) do
               configs_dir.mkpath

               config_path.write clear_yaml
               config_path.chmod 0o600
               secrets_path.write lockbox.encrypt clear_yaml
               secrets_path.chmod 0o600

               key_file = configs_dir / 'master_key'
               key_file.write default_lockbox_key
               key_file.chmod 0o600
            end

            it 'should explode when there are unexpected keys in config' do
               # testing both nested and root keys
               config_path.write <<~YML
                  ---
                  elevenses: false
                  database:
                     name: 'test_db'
                     balrogs: 1
               YML

               expect do
                  described_class.new namespace: name, configs_schema: configs_schema
               end.to raise_error SchemaValidationError, include('Validation errors')
                                                               .and(include(':balrogs is not allowed'))
                                                               .and(include(':elevenses is not allowed'))
            end

            it 'should explode when there are unexpected keys in secrets' do
               # testing both nested and root keys
               secrets_path.write lockbox.encrypt <<~YML
                  ---
                  took: 'fool'
                  database:
                     password: 'sekret'
                     friend: 'mellon'
               YML

               expect do
                  described_class.new namespace: name, configs_schema: configs_schema, secrets_schema: secrets_schema
               end.to raise_error SchemaValidationError, include('Validation errors')
                                                               .and(include(':took is not allowed'))
                                                               .and(include(':friend is not allowed'))
            end

            it 'should validate the loaded configs and secrets' do
               expect do
                  described_class.new namespace: name, configs_schema: configs_schema, secrets_schema: secrets_schema
               end.to raise_error SchemaValidationError, include('Validation errors')
                                                               .and(include(':configs / :database is missing'))
                                                               .and(include(':secrets / :database is missing'))
            end
         end

         context 'config file' do
            it 'should verify the config file permissions' do
               config_path.chmod(0o777)

               expect do
                  described_class.new namespace: name
               end.to raise_error PrivateFile::FilePermissionsError
            end

            context 'config file missing' do
               before :each do
                  config_path.delete
               end

               it 'should explode' do
                  expect do
                     described_class.new namespace: name
                  end.to raise_error MissingConfigFileError, start_with('No Invar config file found.')
               end

               it 'should hint at a solution' do
                  msg = 'Create config.yml in one of these locations'

                  expect do
                     described_class.new namespace: name
                  end.to raise_error MissingConfigFileError, include(msg)
               end

               it 'should state the locations searched' do
                  xdg_config_home = Pathname.new(ENV.fetch('XDG_CONFIG_HOME', XDG::Defaults::CONFIG_HOME)) / name

                  xdg_config_dirs = ENV.fetch('XDG_CONFIG_DIRS', '/something:/someplace')
                  xdg_config_dirs = xdg_config_dirs.split(':').collect { |p| Pathname.new(p) / name }

                  expect do
                     described_class.new namespace: name
                  end.to raise_error MissingConfigFileError, include(xdg_config_home.expand_path.to_s)
                                                                   .and(include(xdg_config_dirs.join(', ')))
               end
            end
         end

         context 'secrets file' do
            before(:each) do
               secrets_path.chmod(0o600)
            end

            it 'should verify the secrets file permissions' do
               config_path.chmod(0o777)

               expect do
                  described_class.new namespace: name
               end.to raise_error PrivateFile::FilePermissionsError
            end

            context 'secrets file missing' do
               before(:each) do
                  secrets_path.delete
               end

               it 'should explode' do
                  expect do
                     described_class.new namespace: name
                  end.to raise_error MissingSecretsFileError, start_with('No Invar secrets file found.')
               end

               it 'should hint at a solution' do
                  msg = 'Create encrypted secrets.yml in one of these locations'

                  expect do
                     described_class.new namespace: name
                  end.to raise_error MissingSecretsFileError, include(msg)
               end

               it ' should state the locations searched ' do
                  xdg_config_home = Pathname.new(ENV.fetch('XDG_CONFIG_HOME', XDG::Defaults::CONFIG_HOME)) / name

                  xdg_config_dirs = ENV.fetch('XDG_CONFIG_DIRS', '/something:/someplace')
                  xdg_config_dirs = xdg_config_dirs.split(':').collect { |p| Pathname.new(p) / name }

                  expect do
                     described_class.new namespace: name
                  end.to raise_error MissingSecretsFileError, include(xdg_config_home.expand_path.to_s)
                                                                    .and(include(xdg_config_dirs.join(', ')))
               end
            end

            context 'encryption key defined' do
               let(:name) { 'test-app' }

               let(:configs_dir) { Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name }
               let(:secrets_path) { configs_dir / 'secrets.yml' }

               before(:each) do
                  config_path = configs_dir / 'config.yml'
                  config_path.dirname.mkpath
                  config_path.write clear_yaml
                  config_path.chmod(0o600)

                  secrets_path.write lockbox.encrypt clear_yaml
                  secrets_path.chmod(0o600)
               end

               it 'should NOT ask for it from STDIN' do
                  expect do
                     described_class.new namespace: name
                  end.to_not output.to_stderr
               end

               it 'should default to the Lockbox master key' do
                  with_lockbox_key default_lockbox_key do
                     expect do
                        described_class.new namespace: name
                     end.to_not output.to_stderr
                  end
               end

               let(:key_file) { Pathname.new('master_key') }
               let(:key_path) { configs_dir / key_file }

               before(:each) do
                  key_path.write default_lockbox_key
                  key_path.chmod 0o0600 # u+rw,go-a
               end

               it 'should read from a Pathname key file' do
                  expect do
                     described_class.new namespace: name, decryption_keyfile: key_file
                  end.to_not output.to_stderr
               end

               # terminal text editors can add a newline at the end a file as default behaviour
               it 'should strip whitespace around the key in a file' do
                  key_path.write "\n\n \t#{ default_lockbox_key }\t \n"

                  expect do
                     described_class.new namespace: name, decryption_keyfile: key_file
                  end.to_not output.to_stderr
               end

               it 'should verify keyfile permissions' do
                  key_path.chmod(0o777)

                  expect do
                     described_class.new namespace: name, decryption_keyfile: key_file
                  end.to raise_error PrivateFile::FilePermissionsError
               end
            end

            context 'encryption key missing' do
               before :each do
                  key_path.delete
                  allow($stdin).to receive(:noecho).and_return default_lockbox_key
                  allow($stdin).to receive(:tty?).and_return(tty_status)
               end

               around :each do |example|
                  with_lockbox_key(nil, &example)
               end

               context 'STDIN is TTY' do
                  let(:tty_status) { true }

                  it 'should ask for it from STDIN' do
                     msg = 'Enter master key to decrypt'

                     expect($stdin).to receive(:noecho).and_return default_lockbox_key

                     expect do
                        described_class.new namespace: name
                     end.to output(start_with(msg)).to_stderr
                  end

                  it 'should mention the file it is decrypting' do
                     path = Pathname.new('~/.config/') / name / 'secrets.yml'

                     expect do
                        described_class.new namespace: name
                     end.to output(include(path.expand_path.to_s)).to_stderr
                  end
               end

               context 'STDIN is not TTY' do
                  let(:tty_status) { false }

                  it 'should raise an error instead of asking' do
                     expect do
                        expect do
                           described_class.new namespace: name
                        end.to raise_error SecretsFileDecryptionError
                     end.to_not output.to_stderr
                  end

                  it 'should have a useful error message' do
                     msg = "Could not find file '#{ Reality::DEFAULT_KEY_FILE_NAME }'."

                     # TODO: Would be better to control the XDG env vars here once something like Climate Control is added
                     search_paths = [XDG::Defaults::CONFIG_HOME]
                     search_paths = (search_paths + ENV.fetch('XDG_CONFIG_DIRS').split(':')).collect do |p|
                        Pathname.new(p).expand_path / name
                     end.join(', ')

                     expect do
                        described_class.new namespace: name
                     end.to raise_error SecretsFileDecryptionError, include(msg).and(include(search_paths))
                  end
               end
            end

            it 'should reraise decryption errors with additional information' do
               secrets_path.write 'badly-encrypted-content'
               secrets_path.chmod 0o600

               msg  = 'Failed to open'
               hint = 'Perhaps you used the wrong file decryption key?'

               expect do
                  described_class.new(namespace: name)
               end.to raise_error SecretsFileDecryptionError,
                                  include(msg).and(include(secrets_path.to_s)).and(include(hint))
            end

            it 'should reraise key argument errors' do
               with_lockbox_key nil do
                  key_path.write '' # empty string is an invalid length key, which should cause a key error

                  expect do
                     described_class.new namespace: name
                  end.to raise_error SecretsFileDecryptionError
               end
            end
         end
      end

      # Base scopes are separately defined in order to enforce a clear delineation between teh two types of
      # information and how carefully to treat it. It also causes an explicit reminder that secrets are secret.
      describe '#/' do
         let(:name) { 'test-app' }
         let(:configs_schema) do
            Dry::Schema.define do
               required :location
            end
         end
         let(:secrets_schema) do
            Dry::Schema.define do
               required :pass
            end
         end
         let(:invar) do
            described_class.new namespace:      name,
                                configs_schema: configs_schema,
                                secrets_schema: secrets_schema
         end
         let(:configs_dir) { Pathname.new('~/.config/test-app').expand_path }
         let(:key_path) { configs_dir / 'master_key' }
         let(:configs_path) { configs_dir / 'config.yml' }
         let(:secrets_path) { configs_dir / 'secrets.yml' }

         before :each do
            configs_path.dirname.mkpath
            configs_path.write <<~YML
               ---
               location: 'Moria'
            YML
            configs_path.chmod 0o600

            secrets_path.dirname.mkpath
            secrets_path.write lockbox.encrypt <<~YML
               ---
               pass: 'mellon'
            YML
            secrets_path.chmod 0o600

            key_path.write default_lockbox_key
            key_path.chmod 0o600
         end

         it 'should have a :config base scope' do
            expect(invar / :config).to be_a Scope
         end

         it 'should have a :secret base scope' do
            expect(invar / :secret).to be_a Scope
         end

         it 'should accept string base scope names' do
            expect(invar / 'config').to be_a Scope
            expect(invar / 'configs').to be_a Scope
            expect(invar / 'secret').to be_a Scope
            expect(invar / 'secrets').to be_a Scope
         end

         # No sense forcing people to remember if its plural or not
         it 'should accept plural base scope names' do
            expect(invar / :configs).to be_a Scope
            expect(invar / :secrets).to be_a Scope
         end

         it 'should ignore case' do
            expect(invar / 'CONFIGS').to be_a Scope
            expect(invar / :configs / 'LOCATION').to eq 'Moria'
         end

         it 'should keep separate :config and :secret scopes' do
            expect(invar / :config).to_not be(invar / :secret)
         end

         it 'should complain about unknown base scope name' do
            msg = 'The root scope name must be either :config or :secret.'
            expect { invar / :database }.to raise_error ArgumentError, msg
         end

         it 'should alias #fetch' do
            expect(invar.fetch(:config)).to be_a Scope
         end

         it 'should alias #[]' do
            expect(invar[:config]).to be_a Scope
         end

         it 'should fetch configs from the file' do
            expect(invar / :config / :location).to eq 'Moria'
         end

         it 'should fetch secrets from the file' do
            expect(invar / :secret / :pass).to eq 'mellon'
         end

         context 'ENV configs' do
            let(:value) { 'some value' }

            around(:each) do |example|
               ENV['TEST_CONFIG'] = value
               example.run
               ENV['TEST_CONFIG'] = nil
            end

            it 'should fetch configs from ENV' do
               expect(invar / :config / 'TEST_CONFIG').to eq value
            end

            it 'should fetch ignoring case' do
               expect(invar / :config / 'test_config').to eq value
            end

            it 'should fetch as symbols' do
               expect(invar / :config / :test_config).to eq value
            end

            it 'should explode if there are collisions with ENV' do
               # testing both uppercase collisions and lowercase collisions
               %w[test_config TEST_CONFIG].each do |key|
                  configs_path.write <<~YML
                     ---
                     #{ key }: 'something'
                  YML

                  msg  = 'Both the environment and your config file have key'
                  hint = EnvConfigCollisionError::HINT

                  expect { invar }.to raise_error(EnvConfigCollisionError,
                                                  include(msg).and(include(key.downcase)).and(include(hint)))
               end
            end
         end
      end
   end
end
