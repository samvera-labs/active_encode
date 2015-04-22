require 'rake/clean'
require 'bundler'

Bundler::GemHelper.install_tasks

task :ci => ['active_encode:adapters:clean', 'active_encode:ci']
task :spec => ['active_encode:ci']

task :default => [:ci]

namespace :active_encode do
  desc "CI build"
  task :ci do
    ENV['environment'] = "test"
    Rake::Task["active_encode:adapters:start"]
    Rake::Task["active_encode:spec"]
  end

  begin
    require 'rspec/core/rake_task'
    RSpec::Core::RakeTask.new(:spec)
  rescue LoadError
  end

  namespace :adapters do
    desc "Clean any local services needed by the adapters"
    task :clean => ['felix:clean']

    desc "Start any local services needed by the adapters"
    task :start => ['felix:start']
  end
end
