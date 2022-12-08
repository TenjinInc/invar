# frozen_string_literal: true

require 'rake'
require 'io/console'
require 'tempfile'
require_relative 'rake_tasks'

namespace :invar do
   namespace :configs do
      desc 'Create a new configuration file'
      task :create, [:namespace] do |task, args|
         Invar::RakeTasks::ConfigTask.new(args[:namespace], task).create
      end

      desc 'Edit the config in your default editor'
      task :edit, [:namespace] do |task, args|
         Invar::RakeTasks::ConfigTask.new(args[:namespace], task).edit
      end
   end

   namespace :secrets do
      desc 'Create a new encrypted secrets file'
      task :create, [:namespace] do |task, args|
         Invar::RakeTasks::SecretTask.new(args[:namespace], task).create
      end

      desc 'Edit the encrypted secrets file in your default editor'
      task :edit, [:namespace] do |task, args|
         Invar::RakeTasks::SecretTask.new(args[:namespace], task).edit
      end
   end

   # aliasing
   namespace :config do
      task :create, [:namespace] => ['configs:create']
      task :edit, [:namespace] => ['configs:edit']
   end
   namespace :secret do
      task :create, [:namespace] => ['secrets:create']
      task :edit, [:namespace] => ['secrets:edit']
   end

   desc 'Show directories to be searched for the given namespace'
   task :paths, [:namespace] do |task, args|
      Invar::RakeTasks::StateTask.new(args[:namespace], task).show_paths
   end
end
