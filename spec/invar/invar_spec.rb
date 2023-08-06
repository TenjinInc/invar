# frozen_string_literal: true

require 'spec_helper'

describe Invar do
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
      config_path.chmod 0o600
      secrets_path.write lockbox.encrypt('---')
      secrets_path.chmod 0o600

      key_path.write default_lockbox_key
      key_path.chmod 0o600
   end

   it 'should have a version number' do
      expect(Invar::VERSION).not_to be nil
   end

   describe '.new' do
      it 'should alias Invar::Invar.new' do
         expect(Invar.new(namespace: name)).to be_a Invar::Reality
      end
   end

   describe '.method_missing' do
      it 'should call super when not a testing method' do
         expect { Invar.asdf }.to raise_error NoMethodError
      end
   end
end
