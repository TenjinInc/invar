# frozen_string_literal: true

require 'spec_helper'

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

      config_path.write '---'
      config_path.chmod 0o600
      secrets_path.binwrite lockbox.encrypt '---'
      secrets_path.chmod 0o600

      key_path.write default_lockbox_key
      key_path.chmod 0o600
   end

   it 'should have a version number' do
      expect(Invar::VERSION).not_to be nil
   end

   describe '.new' do
      around :each do |example|
         test_env = {'XDG_CONFIG_HOME' => test_safe_path('~/.config').to_s}
         ClimateControl.modify test_env, &example
      end

      it 'should alias Invar::Reality.new' do
         expect(Invar.new(namespace: name)).to be_a Invar::Reality
      end
   end

   describe '.method_missing' do
      it 'should call super when not a testing method' do
         expect { Invar.asdf }.to raise_error NoMethodError
      end
   end
end
