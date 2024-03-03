# frozen_string_literal: true

require 'spec_helper'

# Turning off a few rspec cops for this file to keep the test mode stuff together in one place because it uses require
# statements and is a bit fragile.
#
# rubocop:disable RSpec/DescribeClass
# rubocop:disable RSpec/NestedGroups
# rubocop:disable RSpec/DescribedClass
describe 'Invar test extension' do
   let(:name) { 'my-app' }

   context 'when test module is not loaded' do
      describe Invar do
         let(:lockbox) { Lockbox.new(key: SpecHelpers::TEST_LOCKBOX_KEY) }

         let(:configs_dir) do
            test_safe_path('~/.config') / name
         end
         let(:config_path) { configs_dir / 'config.yml' }
         let(:secrets_path) { configs_dir / 'secrets.yml' }

         before do
            configs_dir.mkpath

            config_path.write ' - --'
            config_path.chmod 0o600
            secrets_path.binwrite lockbox.encrypt(' - --')
            secrets_path.chmod 0o600

            key_path = configs_dir / 'master_key'

            key_path.write SpecHelpers::TEST_LOCKBOX_KEY
            key_path.chmod 0o600
         end

         describe '.after_load' do
            it 'should explode when calling the method normally' do
               expect do
                  Invar.after_load do |_|
                     # etc
                  end
               end.to raise_error Invar::ImmutableRealityError, Invar::ImmutableRealityError::HOOK_MSG
            end

            it 'should explode when using #method' do
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

         it 'should raise error as normal for non-test methods when called normally' do
            # using normal calls
            expect do
               Invar.asdf
            end.to raise_error NoMethodError
         end

         it 'should raise error as normal for non-test methods when called using #method' do
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

         it 'should raise error as normal for non-test methods when called normally' do
            expect do
               scope.asdf
            end.to raise_error NoMethodError
         end

         it 'should raise error as normal for non-test methods when called using #method' do
            expect do
               scope.method(:asdf).call
            end.to raise_error NameError
         end
      end
   end

   context 'when test module is loaded' do
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

               expect(Invar::TestExtension::RealityMethods.__after_load_hooks__).to eq [demo_block]
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
         let(:lockbox) { Lockbox.new(key: SpecHelpers::TEST_LOCKBOX_KEY) }

         let(:configs_dir) do
            Pathname.new('~/.config').expand_path / name
         end
         let(:config_path) { configs_dir / 'config.yml' }
         let(:secrets_path) { configs_dir / 'secrets.yml' }

         before do
            configs_dir.mkpath

            config_path.write '---'
            config_path.chmod 0o600
            secrets_path.binwrite lockbox.encrypt('---')
            secrets_path.chmod 0o600

            key_path = configs_dir / 'master_key'

            key_path.write SpecHelpers::TEST_LOCKBOX_KEY
            key_path.chmod 0o600
         end

         around do |example|
            fake_home = test_safe_path '/home/someone'

            ClimateControl.modify('HOME' => fake_home.to_s) do
               example.run
            end
         end

         it 'should run the handler after loading an instance' do
            has_run = false

            Invar.after_load { has_run = true }

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

               stored_values = [scope / :event, scope / :host]

               expect(stored_values).to eq %w[Fireworks Gandalf]
            end

            it 'should convert the key to a symbol' do
               scope.pretend('Event' => 'Fireworks')

               expect(scope / :event).to eq 'Fireworks'
            end

            it 'should convert hashes to a Scope' do
               scope.pretend(entertainment: {type: 'Fireworks', provider: 'Gandalf'})

               expect(scope / :entertainment).to be_a described_class
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

            before do
               scope.pretend(event: 'Disappearance')
            end

            it 'should use pretend values instead of regular ones' do
               expect(scope.to_h).to include(event: 'Disappearance')
            end

            it 'should convert subscopes to hash' do
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
# rubocop:enable RSpec/DescribeClass
# rubocop:enable RSpec/NestedGroups
# rubocop:enable RSpec/DescribedClass
