require 'rake/clean'
require 'bundler'

Bundler::GemHelper.install_tasks

desc "CI build"
task :ci => ["active_encode:adapters:clean", "active_encode:ci"]
desc "Rspec"
task :spec => ["active_encode:ci"]

task :default => [:ci]

namespace 'active_encode' do
  task 'environment' do
    ENV['environment'] = 'test'
  end

  desc "CI build"
  task 'ci' => ["active_encode:environment", "active_encode:adapters:start", "active_encode:spec"]

  begin
    require 'rspec/core/rake_task'
    RSpec::Core::RakeTask.new(:spec)
  rescue LoadError
  end

  namespace 'adapters' do
    desc "Clean any local services needed by the adapters"
    task 'clean' => []

    desc "Start any local services needed by the adapters"
    task 'start' => []
  end
end
