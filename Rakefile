# encoding: utf-8

require "sq/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "yard"
task :doc => :yard

task :default => [:spec, :rubocop]
