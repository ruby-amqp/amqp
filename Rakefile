require 'fileutils'
require 'rspec/core/rake_task'

desc "Run spec suite (uses Rspec2)"
RSpec::Core::RakeTask.new(:spec) { |t|}

namespace :spec do
  desc "Clean up rbx compiled files and run spec suite"
  RSpec::Core::RakeTask.new(:ci) { |t| Dir.glob("**/*.rbc").each {|f| FileUtils.rm_f(f) } }
end

desc "Run specs with RCov"
RSpec::Core::RakeTask.new(:rcov) do |t|
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec']
end

desc "Generate AMQP specification classes"
task :codegen do
  sh 'ruby protocol/codegen.rb > lib/amqp/spec.rb'
  sh 'ruby lib/amqp/spec.rb'
end

desc "Build the gem"
task :gem do
  sh 'gem build *.gemspec'
end

desc "Synonym for gem"
task :pkg => :gem
desc "Synonym for gem"
task :package => :gem


desc "Regenerate contributors file."
task :contributors do
  authors = %x{git log | grep ^Author:}.split("\n")
  results = authors.reduce(Hash.new) do |results, line|
    name = line.sub(/^Author: (.+) <.+>$/, '\1')
    results[name] ||= 0
    results[name] += 1
    results
  end
  results = results.sort_by { |_, count| count }.reverse
  File.open("CONTRIBUTORS", "w") do |file|
    results.each do |name, count|
      file.puts "#{name}: #{count}"
    end
  end
end
