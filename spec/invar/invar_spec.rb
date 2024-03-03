# frozen_string_literal: true

require 'spec_helper'

describe Invar do
   let(:lockbox) { Lockbox.new(key: SpecHelpers::TEST_LOCKBOX_KEY) }

   let(:name) { 'my-app' }
   let(:configs_dir) do
      test_safe_path('~/.config') / name
   end
   let(:config_path) { configs_dir / 'config.yml' }
   let(:secrets_path) { configs_dir / 'secrets.yml' }

   before do
      configs_dir.mkpath

      config_path.write '---'
      config_path.chmod 0o600
      secrets_path.binwrite lockbox.encrypt '---'
      secrets_path.chmod 0o600

      key_path = configs_dir / 'master_key'

      key_path.write SpecHelpers::TEST_LOCKBOX_KEY
      key_path.chmod 0o600
   end

   it 'should have a version number' do
      expect(described_class::VERSION).not_to be_nil
   end

   describe '.new' do
      around do |example|
         test_env = {'XDG_CONFIG_HOME' => test_safe_path('~/.config').to_s}
         ClimateControl.modify test_env, &example
      end

      it 'should alias Invar::Reality.new' do
         expect(described_class.new(namespace: name)).to be_a described_class::Reality
      end
   end

   describe '.method_missing' do
      it 'should call super when not a testing method' do
         expect { described_class.asdf }.to raise_error NoMethodError
      end
   end
end
