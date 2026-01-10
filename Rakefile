# frozen_string_literal: true

begin
  require "bundler/gem_tasks"
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)

  require "rubocop/rake_task"
  RuboCop::RakeTask.new

  task default: %i[spec rubocop]
rescue LoadError
  # Allow rake to work without full dev dependencies
end

desc "Build the gem"
task :build_gem do
  sh "gem build vagrant_utm.gemspec"
end

desc "Install plugin to Vagrant"
task install_plugin: :build_gem do
  sh "vagrant plugin install ./vagrant_utm-*.gem"
end

namespace :test do
  desc "Run macOS acceptance tests (requires macOS + UTM + macOS box)"
  task :macos do
    sh "test/acceptance/macos/run.sh"
  end
end
