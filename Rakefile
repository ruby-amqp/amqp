desc "Generate AMQP specification classes"
task :codegen do
  sh 'ruby protocol/codegen.rb > lib/amqp/spec.rb'
  sh 'ruby lib/amqp/spec.rb'
end

desc "Run spec suite (uses bacon gem)"
task :spec do
  sh 'bacon lib/amqp.rb'
end

desc "Build the gem"
task :gem do
  sh 'gem build *.gemspec'
end

desc "Synonym for gem"
task :pkg => :gem
desc "Synonym for gem"
task :package => :gem