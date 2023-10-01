# frozen_string_literal: true

require 'spec_helper'

describe 'Invar test extension' do
   let(:name) { 'my-app' }

   context 'test module is not loaded' do
      describe Invar do
         let(:default_lockbox_key) { '0' * 64 }
         let(:lockbox) { Lockbox.new(key: default_lockbox_key) }

         let(:name) { 'my-app' }
         let(:configs_dir) do
            test_safe_path('~/.config') / name
         end
         let(:config_path) { configs_dir / 'config.yml' }
         let(:secrets_path) { configs_dir / 'secrets.yml' }
         let(:key_path) { configs_dir / 'master_key' }

         before(:each) do
            configs_dir.mkpath

            config_path.write ' - --'
            config_path.chmod 0o600
            secrets_path.binwrite lockbox.encrypt(' - --')
            secrets_path.chmod 0o600

            key_path.write default_lockbox_key
            key_path.chmod 0o600
         end

         describe '.after_load ' do
            it ' should explode when calling the method normally ' do
               expect do
                  Invar.after_load do |_|
                     # etc
                  end
               end.to raise_error Invar::ImmutableRealityError, Invar::ImmutableRealityError::HOOK_MSG
            end

            it ' should explode when using #method' do
               expect do
                  Invar.method(:after_load).call do |_|
                     # etc
                  end
               end.to raise_error Invar::ImmutableRealityError, Invar::ImmutableRealityError::HOOK_MSG
            end
         end

         describe '.clear_hooks' do
            it 'should explode when calling the method normally' do
               expect do
                  Invar.clear_hooks
               end.to raise_error Invar::ImmutableRealityError, Invar::ImmutableRealityError::HOOK_MSG
            end

            it 'should explode when using #method' do
               expect do
                  Invar.method(:clear_hooks).call
               end.to raise_error Invar::ImmutableRealityError, Invar::ImmutableRealityError::HOOK_MSG
            end
         end

         it 'should raise error as normal for non-test methods' do
            # using normal calls
            expect do
               Invar.asdf
            end.to raise_error NoMethodError

            # and using #method
            expect do
               Invar.method(:asdf).call
            end.to raise_error NameError
         end
      end

      describe Invar::Scope do
         let(:data) do
            {
                  event: 'Birthday',
                  host:  'Bilbo Baggins'
            }
         end
         let(:scope) { described_class.new data }

         describe '#pretend' do
            it 'should explode when calling the method normally' do
               expect do
                  scope.pretend event: 'Disappearance'
               end.to raise_error Invar::ImmutableRealityError, Invar::ImmutableRealityError::PRETEND_MSG
            end

            it 'should explode when using #method' do
               expect do
                  scope.method(:pretend).call event: 'Disappearance'
               end.to raise_error Invar::ImmutableRealityError, Invar::ImmutableRealityError::PRETEND_MSG
            end
         end

         it 'should raise error as normal for non-test methods' do
            # using normal calls
            expect do
               scope.asdf
            end.to raise_error NoMethodError

            # and using #method
            expect do
               scope.method(:asdf).call
            end.to raise_error NameError
         end
      end
   end

   context 'test module is loaded' do
      before do
         require 'invar/test'
      end

      describe Invar do
         describe '.after_load' do
            before do
               Invar.clear_hooks
            end

            it 'should store the handler block' do
               demo_block = proc {}
               Invar.after_load(&demo_block)

               expect(Invar::TestExtension::RealityMethods.__after_load_hooks__.size).to eq 1
               expect(Invar::TestExtension::RealityMethods.__after_load_hooks__).to include demo_block
            end

            it 'should store multiple handler blocks' do
               demo_block1 = proc {}
               demo_block2 = proc {}
               Invar.after_load(&demo_block1)
               Invar.after_load(&demo_block2)

               expect(Invar::TestExtension::RealityMethods.__after_load_hooks__).to eq [demo_block1, demo_block2]
            end
         end

         describe '.clear_hooks' do
            it 'should reset the after_load hook' do
               Invar.clear_hooks
               expect(Invar::TestExtension::RealityMethods.__after_load_hooks__).to be_empty
            end
         end
      end

      describe Invar::Reality do
         let(:default_lockbox_key) { '0' * 64 }
         let(:lockbox) { Lockbox.new(key: default_lockbox_key) }

         let(:name) { 'my-app' }
         let(:configs_dir) do
            Pathname.new('~/.config').expand_path / name
         end
         let(:config_path) { configs_dir / 'config.yml' }
         let(:secrets_path) { configs_dir / 'secrets.yml' }
         let(:key_path) { configs_dir / 'master_key' }

         before(:each) do
            configs_dir.mkpath

            config_path.write '---'
            config_path.chmod 0o600
            secrets_path.binwrite lockbox.encrypt('---')
            secrets_path.chmod 0o600

            key_path.write default_lockbox_key
            key_path.chmod 0o600
         end

         let(:fake_home) { test_safe_path '/home/someone' }

         # TODO: use climate control for this
         around :each do |example|
            with_env('HOME' => fake_home.to_s) do
               example.run
            end
         end

         it 'should run the handler after loading an instance' do
            has_run = false

            Invar.after_load do
               has_run = true
            end

            expect(has_run).to be false
            described_class.new namespace: name
            expect(has_run).to be true
         end
      end

      describe Invar::Scope do
         let(:scope) { described_class.new data }

         describe '#pretend' do
            let(:data) do
               {
                     event: 'Birthday',
                     host:  'Bilbo Baggins'
               }
            end

            it 'should override a data field' do
               scope.pretend(event: 'Disappearance')

               expect(scope / :event).to eq 'Disappearance'
            end

            it 'should override multiple data fields' do
               scope.pretend(event: 'Fireworks', host: 'Gandalf')

               expect(scope / :event).to eq 'Fireworks'
               expect(scope / :host).to eq 'Gandalf'
            end

            it 'should convert the key to a symbol' do
               scope.pretend('Event' => 'Fireworks')

               expect(scope / :event).to eq 'Fireworks'
            end

            it 'should convert hashes to a Scope' do
               scope.pretend(entertainment: {type: 'Fireworks', provider: 'Gandalf'})

               expect(scope / :entertainment).to be_an Invar::Scope
            end
         end

         describe '#fetch' do
            let(:data) do
               {
                     event: 'Birthday',
                     host:  'Bilbo Baggins'
               }
            end

            it 'should convert the key to a symbol' do
               scope.pretend('Event' => 'Fireworks')

               expect(scope / :event).to eq 'Fireworks'
            end

            it 'should return a pretended value' do
               scope.pretend(event: 'Disappearance')

               expect(scope / :event).to eq 'Disappearance'
            end

            it 'should return real values when nothing is pretended' do
               expect(scope / :event).to eq 'Birthday'
            end

            it 'should raise error when key is found in neither' do
               msg = 'key not found: :quest. Known keys are :event, :host. Pretend keys are: (none).'

               expect { scope / :quest }.to raise_error KeyError, msg
            end

            it 'should include pretend key in the error message' do
               scope.pretend(event: 'Disappearance', host: 'Tooks')

               expect { scope / :quest }.to raise_error KeyError, end_with('Pretend keys are: :event, :host.')
            end
         end

         describe '#to_h' do
            let(:data) do
               {
                     event:         'Birthday',
                     host:          'Bilbo Baggins',
                     entertainment: {
                           provider: 'Gandalf',
                           show:     'Fireworks'
                     }
               }
            end

            it 'should use pretend values instead of regular ones' do
               scope.pretend(event: 'Disappearance')

               expect(scope.to_h).to include(event: 'Disappearance')
            end

            it 'should convert subscopes to hash' do
               scope.pretend(event: 'Disappearance')
               scope[:entertainment].pretend(show: 'Magic')

               expected = {
                     event:         'Disappearance',
                     host:          'Bilbo Baggins',
                     entertainment: {
                           provider: 'Gandalf',
                           show:     'Magic'
                     }
               }

               expect(scope.to_h).to eq expected
            end
         end
      end
   end
end
