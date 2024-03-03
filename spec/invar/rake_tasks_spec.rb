# frozen_string_literal: true

require 'spec_helper'

# Intentionally kept separate from main lib require so that folks can use the rake tasks optionally
require 'invar/rake/tasks'

module Invar
   module Rake
      describe 'Rake Tasks Macro' do
         let(:name) { 'test-app' }

         describe '.define' do
            it 'should create an instance and call #define on it' do
               instance = double('tasks instance')
               allow(Invar::Rake::Tasks).to receive(:new).and_return instance

               expect(instance).to receive(:define)

               Invar::Rake::Tasks.define(namespace: name)
            end
         end

         describe '#define' do
            it 'should explode if the namespace argument is nil' do
               msg = ':namespace keyword argument cannot be nil'
               expect { Invar::Rake::Tasks.define namespace: nil }.to raise_error ArgumentError, include(msg)
            end

            it 'should explode if the namespace argument is empty string' do
               msg = ':namespace keyword argument cannot be empty string'
               expect { Invar::Rake::Tasks.define namespace: '' }.to raise_error ArgumentError, include(msg)
            end

            it 'should define an init task' do
               expect(::Rake::Task.task_defined?('invar:init')).to be true
            end

            it 'should define a configs edit task' do
               expect(::Rake::Task.task_defined?('invar:configs')).to be true
            end

            it 'should alias config to configs' do
               expect(::Rake::Task.task_defined?('invar:config')).to be true
            end

            it 'should define a secrets edit task' do
               expect(::Rake::Task.task_defined?('invar:secrets')).to be true
            end

            it 'should alias secret to secrets' do
               expect(::Rake::Task.task_defined?('invar:secret')).to be true
            end

            it 'should define a key rotation task' do
               expect(::Rake::Task.task_defined?('invar:rotate')).to be true
            end

            it 'should define paths info task' do
               expect(::Rake::Task.task_defined?('invar:paths')).to be true
            end
         end
      end
   end
end
