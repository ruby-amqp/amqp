require 'pathname'

NAME = 'amqp'
BASE_PATH = Pathname.new(__FILE__).dirname
LIB_PATH =  BASE_PATH + 'lib'
PKG_PATH =  BASE_PATH + 'pkg'
DOC_PATH =  BASE_PATH + 'rdoc'

$LOAD_PATH.unshift LIB_PATH.to_s unless $LOAD_PATH.include? LIB_PATH.to_s

require 'amqp/version'

CLASS_NAME = AMQP
VERSION = CLASS_NAME::VERSION

require 'rake'

# Load rakefile tasks
Dir['tasks/*.rake'].sort.each { |file| load file }

desc "Generate AMQP specification classes"
task :codegen do
  sh 'ruby protocol/codegen.rb > lib/amqp/spec.rb'
  sh 'ruby lib/amqp/spec.rb'
end

desc "Run spec suite (uses bacon gem)"
task :test do
  sh 'bacon lib/amqp.rb'
end
