# frozen_string_literal: true

require 'spec_helper'

module Dirt
   describe Envelope do
      let(:default_lockbox_key) { '0000000000000000000000000000000000000000000000000000000000000000' }

      it 'should have a version number' do
         expect(Dirt::Envelope::VERSION).not_to be nil
      end

      describe '.override' do
         let(:config_content) do
            <<~YML
               ---
               database:
                  name: dev_database
                  hostname: localhost
            YML
         end

         before(:each) do
            configs_dir = Pathname.new('~/.config').expand_path / 'test-app'
            configs_dir.mkpath
            configs_file = configs_dir / 'config.yml'
            secrets_file = configs_dir / 'secrets.yml'

            configs_file.write config_content
            box = Lockbox.new(key: default_lockbox_key)
            secrets_file.write box.encrypt <<~YML
               ---
            YML
         end

         after(:each) do
            Envelope.after_load do
               # nothing
            end
         end

         it 'should allow an override' do
            new_db_name = 'test_database'

            Envelope.after_load do |envelope|
               (envelope / :config / :database).override name: new_db_name
            end
            envelope = Envelope::Envelope.new(namespace: 'test-app', decryption_key: default_lockbox_key)

            expect(envelope / :configs / :database / :name).to eq new_db_name
         end

         it 'should only override the relevant info' do
            new_db_name = 'test_database'

            Envelope.after_load do |envelope|
               (envelope / :config / :database).override name: new_db_name
            end
            envelope = Envelope::Envelope.new(namespace: 'test-app', decryption_key: default_lockbox_key)

            expect(envelope / :configs / :database / :hostname).to eq 'localhost'
         end
      end
   end

   module Envelope
      describe Envelope do
         let(:default_lockbox_key) { '0000000000000000000000000000000000000000000000000000000000000000' }
         let(:clear_yaml) do
            <<~YML
               ---
            YML
         end
         # This is the encrypted version of a triple-dash empty YAML file under the testing all-zeroes key
         let(:encrypted_yaml) do
            "\xF6\xA6qMs5\x0F\x1Fl\xDAS\xE5\xE1x\x8B\x82\xA2^\xF5\x8B%\xDB\x06\xEA$T/\xCF\x14\x98\x9C\xB1"
         end

         describe '#initialize' do
            it 'should explode when namespace missing' do
               expect { described_class.new }.to raise_error ArgumentError, 'missing keyword: :namespace'
            end

            # Immutability enables safe use in multithreaded situations (like a webserver)
            # and just general state & behaviour predictability.
            # It does not, however, guarantee the actual stored values are also frozen.
            it 'should freeze the ENVelope after creation' do
               config_path = Pathname.new('~/.config/test-app/config.yml').expand_path
               config_path.dirname.mkpath
               config_path.write clear_yaml

               secrets_path = Pathname.new('~/.config/test-app/secrets.yml').expand_path
               secrets_path.dirname.mkpath
               secrets_path.write encrypted_yaml

               envelope = described_class.new namespace: 'test-app', decryption_key: default_lockbox_key

               expect(envelope).to be_frozen
            end

            context 'config file' do
               context 'config file missing' do
                  let(:name) { 'my-app' }

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
               context 'secrets file missing' do
                  let(:name) { 'my-app' }

                  before(:each) do
                     config_path = Pathname.new('~/.config/my-app/config.yml').expand_path
                     config_path.dirname.mkpath
                     config_path.write <<~YML
                        ---
                     YML
                  end

                  it 'should explode' do
                     expect do
                        described_class.new namespace: name, decryption_key: default_lockbox_key
                     end.to raise_error MissingSecretsFileError, start_with('No secrets file found.')
                  end

                  it 'should hint at a solution' do
                     msg = 'Create encrypted secrets.yml in one of these locations'

                     expect do
                        described_class.new namespace: name, decryption_key: default_lockbox_key
                     end.to raise_error MissingSecretsFileError, include(msg)
                  end

                  it 'should state the locations searched' do
                     xdg_config_home = Pathname.new(ENV.fetch('XDG_CONFIG_HOME', XDG::Defaults::CONFIG_HOME)) / name

                     xdg_config_dirs = ENV.fetch('XDG_CONFIG_DIRS', '/something:/someplace')
                     xdg_config_dirs = xdg_config_dirs.split(':').collect { |p| Pathname.new(p) / name }

                     expect do
                        described_class.new namespace: name, decryption_key: default_lockbox_key
                     end.to raise_error MissingSecretsFileError, include(xdg_config_home.expand_path.to_s)
                                                                       .and(include(xdg_config_dirs.join(', ')))
                  end
               end

               context 'encryption key defined' do
                  let(:name) { 'test-app' }

                  let(:secrets_path) { Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name / 'secrets.yml' }

                  before(:each) do
                     config_path = Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name / 'config.yml'
                     config_path.dirname.mkpath
                     config_path.write clear_yaml

                     secrets_path.write encrypted_yaml
                  end

                  it 'should NOT ask for it from STDIN' do
                     expect do
                        described_class.new namespace: name, decryption_key: default_lockbox_key
                     end.to_not output.to_stderr
                  end

                  it 'should default to the Lockbox master key' do
                     old_key            = Lockbox.master_key
                     Lockbox.master_key = default_lockbox_key

                     expect do
                        described_class.new namespace: name
                     end.to_not output.to_stderr

                     Lockbox.master_key = old_key
                  end
               end

               context 'encryption key missing' do
                  let(:name) { 'test-app' }

                  let(:secrets_path) { Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name / 'secrets.yml' }

                  before(:each) do
                     config_path = Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name / 'config.yml'
                     config_path.dirname.mkpath
                     config_path.write clear_yaml

                     secrets_path.write encrypted_yaml
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
                        described_class.new namespace: name
                        $stdin = STDIN
                     end.to output(start_with(msg)).to_stderr
                  end

                  it 'should mention the file it is decrypting' do
                     path = Pathname.new('~/.config/') / name / 'secrets.yml'

                     expect do
                        $stdin = double('fake IO', noecho: default_lockbox_key)
                        described_class.new namespace: name
                        $stdin = STDIN
                     end.to output(include(path.expand_path.to_s)).to_stderr
                  end

                  it 'should read the password from STDIN without echo' do
                     input = double('fake input')

                     $stdin = input

                     expect(input).to receive(:noecho).and_return default_lockbox_key

                     $stderr = StringIO.new
                     described_class.new namespace: name
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
                  name        = 'test-app'
                  configs_dir = Pathname.new(XDG::Defaults::CONFIG_HOME).expand_path / name
                  configs_dir.mkpath

                  config_path = configs_dir / 'config.yml'
                  config_path.write clear_yaml

                  secrets_path = configs_dir / 'secrets.yml'
                  secrets_path.write 'badly-encrypted-content'

                  msg  = 'Failed to open'
                  hint = 'Perhaps you used the wrong file decryption key?'

                  expect do
                     described_class.new(namespace: name, decryption_key: default_lockbox_key)
                  end.to raise_error(SecretsFileDecryptionError,
                                     include(msg).and(include(secrets_path.to_s)).and(include(hint)))
               end
            end
         end

         # Base scopes are separately defined in order to enforce a clear delineation between teh two types of
         # information and how carefully to treat it. It also causes an explicit reminder that secrets are secret.
         describe '#/' do
            let(:name) { 'test-app' }
            let(:envelope) { described_class.new namespace: name, decryption_key: default_lockbox_key }
            let(:configs_path) { Pathname.new('~/.config/test-app/config.yml').expand_path }
            let(:secrets_path) { Pathname.new('~/.config/test-app/secrets.yml').expand_path }

            before(:each) do
               configs_path.dirname.mkpath
               configs_path.write <<~YML
                  ---
                  location: 'Moria'
               YML

               box = Lockbox.new(key: default_lockbox_key)
               secrets_path.dirname.mkpath
               secrets_path.write box.encrypt <<~YML
                  ---
                  pass: 'mellon'
               YML
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
