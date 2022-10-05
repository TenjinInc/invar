# frozen_string_literal: true

require 'spec_helper'

# Intentionally kept separate from main lib require so that folks can use the rake tasks optionally
require 'dirt/envelope/rake'

describe 'Rake Tasks' do
   let(:name) { 'test-app' }

   before(:each) do
      task.reenable
   end

   context 'envelope:configs:create' do
      let(:task) { ::Rake::Task['envelope:configs:create'] }

      it 'should define a configs create task' do
         expect(::Rake::Task.task_defined?('envelope:configs:create')).to be true
      end

      it 'should explode if the namespace argument is missing' do
         msg = "namespace argument required. Run with: bundle exec rake #{ task.name }[namespace_here]"
         expect { task.invoke }.to raise_error ArgumentError, msg
      end

      context '$HOME is defined' do
         let(:configs_dir) { Pathname.new(Dirt::Envelope::XDG::Defaults::CONFIG_HOME).expand_path / name }

         it 'should create a config file in the XDG_CONFIG_HOME path' do
            task.invoke(name)

            expect(configs_dir / 'config.yml').to exist
         end

         it 'should state the file it created' do
            config_path = configs_dir / 'config.yml'

            expect { task.invoke(name) }.to output(include(config_path.to_s)).to_stderr
         end

         it 'should abort if the file already exists' do
            config_path = configs_dir / 'config.yml'
            configs_dir.mkpath
            config_path.write ''

            msg = <<~MSG
               Abort: File exists. (#{ config_path })
               Maybe you meant to edit the file with rake envelope:secrets:edit?
            MSG
            expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
         end
      end

      context '$HOME is undefined' do
         let(:configs_dir) do
            xdg_default = Dirt::Envelope::XDG::Defaults::CONFIG_DIRS
            Pathname.new(ENV.fetch('XDG_CONFIG_DIRS', xdg_default).split(':').first).expand_path / name
         end

         around(:each) do |example|
            old_home = Dir.home
            ENV.delete('HOME')
            example.run
            ENV['HOME'] = old_home
         end

         it 'should create a config file in the first XDG_CONFIG_DIRS path' do
            task.invoke(name)

            expect(configs_dir / 'config.yml').to exist
         end

         it 'should state the file it created' do
            config_path = configs_dir / 'config.yml'

            expect { task.invoke(name) }.to output(include(config_path.to_s)).to_stderr
         end
      end
   end

   context 'envelope:configs:edit' do
      let(:task) { ::Rake::Task['envelope:configs:edit'] }

      before(:each) do
         # Prevent it from opening actual editor
         allow(Dirt::Envelope::RakeTasks).to receive(:system)
      end

      it 'should define a configs edit task' do
         expect(::Rake::Task.task_defined?('envelope:configs:edit')).to be true
      end

      it 'should explode if the namespace argument is missing' do
         msg = "namespace argument required. Run with: bundle exec rake #{ task.name }[namespace_here]"
         expect { task.invoke }.to raise_error ArgumentError, msg
      end

      context '$HOME is defined' do
         let(:configs_dir) { Pathname.new(Dirt::Envelope::XDG::Defaults::CONFIG_HOME).expand_path / name }
         let(:config_path) { configs_dir / 'config.yml' }

         before(:each) do
            configs_dir.mkpath
            config_path.write ''
         end

         it 'should edit the config file in the XDG_CONFIG_HOME path' do
            # the intention of 'exception: true' is to noisily fail, which can be useful when automating
            expect(Dirt::Envelope::RakeTasks).to receive(:system).with('editor', config_path.to_s, exception: true)

            task.invoke(name)
         end

         it 'should abort if the file does not exist' do
            config_path.delete

            xdg_home = ENV.fetch('XDG_CONFIG_HOME', Dirt::Envelope::XDG::Defaults::CONFIG_HOME)
            xdg_dirs = ENV.fetch('XDG_CONFIG_DIRS', Dirt::Envelope::XDG::Defaults::CONFIG_DIRS).split(':')

            search_path = [Pathname.new(xdg_home).expand_path / name].concat(xdg_dirs.collect { |p| Pathname.new(p) / name })

            msg = <<~MSG
               Abort: Could not find #{ config_path.basename }. Searched in: #{ search_path.join(', ') }
               Maybe you used the wrong namespace or need to create the file with bundle exec rake envelope:configs:create?
            MSG

            expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
         end

         it 'should state the file saved' do
            config_path = configs_dir / 'config.yml'

            expect { task.invoke(name) }.to output(include(config_path.to_s)).to_stderr
         end
      end

      context '$HOME is undefined' do
         let(:search_path) do
            ENV.fetch('XDG_CONFIG_DIRS', Dirt::Envelope::XDG::Defaults::CONFIG_DIRS).split(':').collect do |p|
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
            expect(Dirt::Envelope::RakeTasks).to receive(:system).with('editor', config_path.to_s, exception: true)

            task.invoke(name)
         end

         it 'should abort if the file does not exist' do
            config_path.delete

            msg = <<~MSG
               Abort: Could not find #{ config_path.basename }. Searched in: #{ search_path.join(', ') }
               Maybe you used the wrong namespace or need to create the file with bundle exec rake envelope:configs:create?
            MSG

            expect { task.invoke(name) }.to output(msg).to_stderr.and(raise_error(SystemExit))
         end

         it 'should state the file saved' do
            expect { task.invoke(name) }.to output(include(config_path.to_s)).to_stderr
         end
      end
   end

   context 'envelope:secrets:create' do
      let(:task) { ::Rake::Task['envelope:secrets:create'] }

      it 'should define a secrets create task' do
         expect(::Rake::Task.task_defined?('envelope:secrets:create')).to be true
      end

      it 'should explode if the namespace argument is missing' do
         msg = "namespace argument required. Run with: bundle exec rake #{ task.name }[namespace_here]"
         expect { task.invoke }.to raise_error ArgumentError, msg
      end

      context '$HOME is defined' do
         it 'should create a secrets file in the XDG_CONFIG_HOME path'
      end

      context '$HOME is undefined' do
         it 'should create a secrets file in the first XDG_CONFIG_DIRS path'
      end
   end

   context 'envelope:secrets:edit' do
      let(:task) { ::Rake::Task['envelope:secrets:edit'] }

      it 'should define a secrets edit task' do
         expect(::Rake::Task.task_defined?('envelope:secrets:edit')).to be true
      end

      it 'should explode if the namespace argument is missing' do
         msg = "namespace argument required. Run with: bundle exec rake #{ task.name }[namespace_here]"
         expect { task.invoke }.to raise_error ArgumentError, msg
      end

      context '$HOME is defined' do
         it 'should edit the secrets file in the XDG_CONFIG_HOME path'
      end

      context '$HOME is undefined' do
         it 'should edit the secrets file in the first XDG_CONFIG_DIRS path'
      end
   end
end
