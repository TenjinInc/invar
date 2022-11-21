# frozen_string_literal: true

require 'spec_helper'

module Dirt
   describe Envelope do
      let(:default_lockbox_key) { '0' * 64 }
      let(:lockbox) { Lockbox.new(key: default_lockbox_key) }

      let(:name) { 'my-app' }
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
         secrets_path.write lockbox.encrypt('---')

         key_path.write default_lockbox_key
         key_path.chmod 0o600
      end

      it 'should have a version number' do
         expect(Dirt::Envelope::VERSION).not_to be nil
      end

      describe '.new' do
         it 'should alias Envelope::Envelope.new' do
            expect(Envelope.new(namespace: name)).to be_a Envelope::Envelope
         end
      end

      describe '.after_load' do
         it 'should run the handler after loading an instance' do
            has_run = false

            Envelope.after_load do
               has_run = true
            end

            expect(has_run).to be false
            described_class.new namespace: name
            expect(has_run).to be true
         end
      end
   end

   module Envelope
      describe Envelope do
         let(:name) { 'my-app' }
         let(:default_lockbox_key) { '0' * 64 }
         let(:lockbox) { Lockbox.new(key: default_lockbox_key) }
         let(:clear_yaml) do
            <<~YML
               ---
            YML
         end

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
            it 'should freeze the ENVelope after creation' do
               configs_dir.mkpath

               config_path.write clear_yaml
               secrets_path.write lockbox.encrypt clear_yaml

               key_file = configs_dir / 'master_key'
               key_file.write default_lockbox_key
               key_file.chmod 0o600

               envelope = described_class.new namespace: name do
                  required(:configs)
                  required(:secrets)
               end

               expect(envelope).to be_frozen
            end

            context 'schema' do
               before(:each) do
                  configs_dir.mkpath

                  config_path.write clear_yaml
                  secrets_path.write lockbox.encrypt clear_yaml

                  key_file = configs_dir / 'master_key'
                  key_file.write default_lockbox_key
                  key_file.chmod 0o600
               end

               it 'should explode when there are unexpected keys in config' do
                  config_path.write <<~YML
                     ---
                     something: 'else'
                     database:
                        name: 'test_db'
                  YML

                  configs_schema = Dry::Schema.define do
                     required(:database).hash do
                        required(:name).filled
                     end
                  end

                  secrets_schema = Dry::Schema.define do
                     required(:password).filled
                  end

                  expect do
                     described_class.new namespace: name, configs_schema: configs_schema, secrets_schema: secrets_schema
                  end.to raise_error SchemaValidationError, include('Validation errors')
                                                                  .and(include(':something is not allowed'))
               end

               it 'should explode when there are unexpected keys in secrets' do
                  secrets_path.write lockbox.encrypt <<~YML
                     ---
                     something: 'else'
                     database:
                        password: 'sekret'
                  YML

                  configs_schema = Dry::Schema.define do
                     required(:database).hash do
                        required(:name).filled
                     end
                  end

                  secrets_schema = Dry::Schema.define do
                     required(:database).hash do
                        required(:password).filled
                     end
                  end

                  expect do
                     described_class.new namespace: name, configs_schema: configs_schema, secrets_schema: secrets_schema
                  end.to raise_error SchemaValidationError, include('Validation errors')
                                                                  .and(include(':something is not allowed'))
               end

               it 'should validate the loaded settings' do
                  expect do
                     configs_schema = Dry::Schema.define do
                        required(:database).hash do
                           required(:name).filled
                        end
                     end

                     secrets_schema = Dry::Schema.define do
                        required(:database).hash do
                           required(:password).filled
                        end
                     end

                     described_class.new namespace: name, configs_schema: configs_schema, secrets_schema: secrets_schema
                  end.to raise_error SchemaValidationError, include('Validation errors')
                                                                  .and(include(':configs / :database is missing'))
                                                                  .and(include(':secrets / :database is missing'))
               end
            end

            context 'config file' do
               context 'config file missing' do
                  it 'should explode' do
                     expect do
                        described_class.new namespace: name
                     end.to raise_error MissingConfigFileError, start_with('No config file found.')
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
               let(:name) { 'test-app' }
               let(:configs_dir) { Pathname.new('~/.config/').expand_path / name }

               before(:each) do
                  configs_dir.mkpath
               end

               context 'secrets file missing' do
                  before(:each) do
                     config_path = configs_dir / 'config.yml'
                     config_path.dirname.mkpath
                     config_path.write <<~YML
                        ---
                     YML
                  end

                  it 'should explode' do
                     expect do
                        described_class.new namespace: name
                     end.to raise_error MissingSecretsFileError, start_with('No secrets file found.')
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

                     secrets_path.write lockbox.encrypt clear_yaml
                  end

                  it 'should NOT ask for it from STDIN' do
                     expect do
                        described_class.new namespace: name do
                           required(:configs)
                           required(:secrets)
                        end
                     end.to_not output.to_stderr
                  end

                  it 'should default to the Lockbox master key' do
                     old_key            = Lockbox.master_key
                     Lockbox.master_key = default_lockbox_key

                     expect do
                        described_class.new namespace: name do
                           required(:configs)
                           required(:secrets)
                        end
                     end.to_not output.to_stderr

                     Lockbox.master_key = old_key
                  end

                  let(:key_file) { Pathname.new('master_key') }
                  let(:key_path) { configs_dir / key_file }

                  before(:each) do
                     key_path.write default_lockbox_key
                     key_path.chmod 0o0600 # u+rw,go-a
                  end

                  it 'should read from a Pathname key file' do
                     expect do
                        described_class.new namespace: name, decryption_keyfile: key_file do
                           required(:configs)
                           required(:secrets)
                        end
                     end.to_not output.to_stderr
                  end

                  # terminal text editors can add a newline at the end a file as default behaviour
                  it 'should strip whitespace around the key in a file' do
                     key_path.write "\n\n \t#{ default_lockbox_key }\t \n"

                     expect do
                        described_class.new namespace: name, decryption_keyfile: key_file do
                           required(:configs)
                           required(:secrets)
                        end
                     end.to_not output.to_stderr
                  end

                  it 'should NOT complain when keyfile has proper permissions' do
                     [0o400, 0o600].each do |mode|
                        key_path.chmod(mode)

                        expect do
                           described_class.new namespace: name, decryption_keyfile: key_file do
                              required(:configs)
                              required(:secrets)
                           end
                        end.to_not raise_error
                     end
                  end

                  context 'improper permissions' do
                     # Generating each test instance separately to be very explicit about each one being tested.
                     # Could have gotten fancy and calculate it, but tests should be clear.
                     # Testing each mode segment individually and not testing the combos because that is a bit slow
                     # and redundant.
                     # Each is an octal mode triplet [User, Group, Others].
                     illegal_modes = [0o000, 0o001, 0o002, 0o003, 0o004, 0o005, 0o006, 0o007, # world / others
                                      0o000, 0o010, 0o020, 0o030, 0o040, 0o050, 0o060, 0o070, # group
                                      0o000, 0o100, 0o200, 0o300, 0o500, 0o700] # user
                     illegal_modes.each do |mode|
                        it "should complain when keyfile has mode #{ format('%04o', mode) }" do
                           key_path.chmod(mode)

                           # '%04o' is string formatter speak for "4-digit octal"
                           msg = format("File '%<path>s' has improper permissions (%<mode>04o).",
                                        path: key_path, mode: mode)

                           expect do
                              described_class.new namespace: name, decryption_keyfile: key_file
                           end.to raise_error SecretsFileDecryptionError,
                                              include(msg).and(include('chmod'))
                        end
                     end
                  end
               end

               context 'encryption key missing' do
                  let(:secrets_path) { Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name / 'secrets.yml' }

                  before(:each) do
                     config_path = Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name / 'config.yml'
                     config_path.dirname.mkpath
                     config_path.write clear_yaml

                     secrets_path.write lockbox.encrypt clear_yaml
                  end

                  around(:each) do |example|
                     old_key            = Lockbox.master_key
                     Lockbox.master_key = nil
                     example.run
                     Lockbox.master_key = old_key
                  end

                  it 'should ask for it from STDIN' do
                     msg = 'Enter master key to decrypt'

                     expect do
                        $stdin = double('fake IO', noecho: default_lockbox_key)
                        described_class.new namespace: name do
                           required(:configs)
                           required(:secrets)
                        end
                        $stdin = STDIN
                     end.to output(start_with(msg)).to_stderr
                  end

                  it 'should mention the file it is decrypting' do
                     path = Pathname.new('~/.config/') / name / 'secrets.yml'

                     expect do
                        $stdin = double('fake IO', noecho: default_lockbox_key)
                        described_class.new namespace: name do
                           required(:configs)
                           required(:secrets)
                        end
                        $stdin = STDIN
                     end.to output(include(path.expand_path.to_s)).to_stderr
                  end

                  it 'should read the password from STDIN without echo' do
                     input = double('fake input')

                     $stdin = input

                     expect(input).to receive(:noecho).and_return default_lockbox_key

                     $stderr = StringIO.new
                     described_class.new namespace: name do
                        required(:configs)
                        required(:secrets)
                     end
                     $stderr = STDERR

                     $stdin = STDIN
                  end

                  context 'STDIN cannot #noecho' do
                     let(:input) { StringIO.new }

                     around(:each) do |example|
                        $stdin = input
                        example.run
                        $stdin = STDIN
                     end

                     it 'should raise an error instead of asking' do
                        expect do
                           expect do
                              described_class.new namespace: name
                           end.to(raise_error(SecretsFileDecryptionError))
                        end.to_not output.to_stderr
                     end
                  end
               end

               it 'should reraise decryption errors with additional information' do
                  config_path = configs_dir / 'config.yml'
                  config_path.write clear_yaml

                  secrets_path = configs_dir / 'secrets.yml'
                  secrets_path.write 'badly-encrypted-content'

                  key_path = configs_dir / 'master_key'
                  key_path.write default_lockbox_key
                  key_path.chmod 0o600

                  msg  = 'Failed to open'
                  hint = 'Perhaps you used the wrong file decryption key?'

                  expect do
                     described_class.new(namespace: name)
                  end.to raise_error(SecretsFileDecryptionError,
                                     include(msg).and(include(secrets_path.to_s)).and(include(hint)))
               end

               it 'should reraise key argument errors' do
                  config_path = configs_dir / 'config.yml'
                  config_path.write clear_yaml

                  secrets_path = configs_dir / 'secrets.yml'
                  secrets_path.write lockbox.encrypt clear_yaml

                  key_path = configs_dir / 'master_key'
                  FileUtils.touch key_path # empty is invalid length key
                  key_path.chmod 0o600

                  expect do
                     described_class.new namespace: name
                  end.to raise_error SecretsFileDecryptionError
               end
            end
         end

         # Base scopes are separately defined in order to enforce a clear delineation between teh two types of
         # information and how carefully to treat it. It also causes an explicit reminder that secrets are secret.
         describe '#/' do
            let(:name) { 'test-app' }
            let(:configs_schema) do
               Dry::Schema.define do
                  required(:location)
               end
            end
            let(:secrets_schema) do
               Dry::Schema.define do
                  required(:pass)
               end
            end
            let(:envelope) do
               described_class.new namespace:      name,
                                   configs_schema: configs_schema,
                                   secrets_schema: secrets_schema
            end
            let(:configs_dir) { Pathname.new('~/.config/test-app').expand_path }
            let(:key_path) { configs_dir / 'master_key' }
            let(:configs_path) { configs_dir / 'config.yml' }
            let(:secrets_path) { configs_dir / 'secrets.yml' }

            before(:each) do
               configs_path.dirname.mkpath
               configs_path.write <<~YML
                  ---
                  location: 'Moria'
               YML

               secrets_path.dirname.mkpath
               secrets_path.write lockbox.encrypt <<~YML
                  ---
                  pass: 'mellon'
               YML

               key_path.write default_lockbox_key
               key_path.chmod 0o600
            end

            it 'should have a :config base scope' do
               expect(envelope / :config).to be_a Scope
            end

            it 'should have a :secret base scope' do
               expect(envelope / :secret).to be_a Scope
            end

            it 'should accept string base scope names' do
               expect(envelope / 'config').to be_a Scope
               expect(envelope / 'configs').to be_a Scope
               expect(envelope / 'secret').to be_a Scope
               expect(envelope / 'secrets').to be_a Scope
            end

            # No sense forcing people to remember if its plural or not
            it 'should accept plural base scope names' do
               expect(envelope / :configs).to be_a Scope
               expect(envelope / :secrets).to be_a Scope
            end

            it 'should ignore case' do
               expect(envelope / 'CONFIGS').to be_a Scope
               expect(envelope / :configs / 'LOCATION').to eq 'Moria'
            end

            it 'should keep separate :config and :secret scopes' do
               expect(envelope / :config).to_not be(envelope / :secret)
            end

            it 'should complain about unknown base scope name' do
               msg = 'The root scope name must be either :config or :secret.'
               expect { envelope / :database }.to raise_error ArgumentError, msg
            end

            it 'should alias #fetch' do
               expect(envelope.fetch(:config)).to be_a Scope
            end

            it 'should alias #[]' do
               expect(envelope[:config]).to be_a Scope
            end

            it 'should fetch configs from the file' do
               expect(envelope / :config / :location).to eq 'Moria'
            end

            it 'should fetch secrets from the file' do
               expect(envelope / :secret / :pass).to eq 'mellon'
            end

            context 'ENV configs' do
               let(:value) { 'some value' }

               around(:each) do |example|
                  ENV['TEST_CONFIG'] = value
                  example.run
                  ENV['TEST_CONFIG'] = nil
               end

               it 'should fetch configs from ENV' do
                  expect(envelope / :config / 'TEST_CONFIG').to eq value
               end

               it 'should fetch ignoring case' do
                  expect(envelope / :config / 'test_config').to eq value
               end

               it 'should fetch as symbols' do
                  expect(envelope / :config / :test_config).to eq value
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

                     expect { envelope }.to raise_error(EnvConfigCollisionError,
                                                        include(msg).and(include(key.downcase)).and(include(hint)))
                  end
               end
            end
         end
      end
   end
end
