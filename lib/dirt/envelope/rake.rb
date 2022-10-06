# frozen_string_literal: true

require 'rake'
require 'io/console'
require 'tempfile'
require_relative 'rake_tasks'

namespace :envelope do
   namespace :configs do
      desc 'Create a new configuration file'
      task :create, [:namespace] do |_task, args|
         Dirt::Envelope::RakeTasks.create_config(args[:namespace])
      end

      desc 'Edit the config in your default editor'
      task :edit, [:namespace] do |_task, args|
         Dirt::Envelope::RakeTasks.edit_config(args[:namespace])
      end
   end

   namespace :secrets do
      desc 'Create a new encrypted secrets file'
      task :create, [:namespace] do |_task, args|
         Dirt::Envelope::RakeTasks.create_secret(args[:namespace])
      end

      desc 'Edit the encrypted secrets file in your default editor'
      task :edit, [:namespace] do |_task, args|
         Dirt::Envelope::RakeTasks.edit_secret(args[:namespace])
      end
   end

   desc 'Show directories to be searched for the given namespace'
   task :paths, [:namespace] do |_task, args|
      Dirt::Envelope::RakeTasks.show_paths(args[:namespace])
   end
end
