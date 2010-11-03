desc 'Alias to spec:spec'
task :spec => 'spec:spec'

namespace :spec do
  require 'rspec/core/rake_task'

  desc "Run all specs"
  RSpec::Core::RakeTask.new(:spec){|task|}

  desc "Run specs with RCov"
  RSpec::Core::RakeTask.new(:rcov) do |t|
    t.rcov = true
    t.rcov_opts = ['--exclude', 'spec']
  end
end
