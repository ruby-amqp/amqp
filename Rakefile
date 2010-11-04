require 'rake'
require 'pathname'

BASE_PATH = Pathname.new(__FILE__).dirname
LIB_PATH =  BASE_PATH + 'lib'
PKG_PATH =  BASE_PATH + 'pkg'
DOC_PATH =  BASE_PATH + 'rdoc'

$LOAD_PATH.unshift LIB_PATH.to_s unless $LOAD_PATH.include? LIB_PATH.to_s

require 'amqp/version'

NAME = 'arvicco-amqp'
CLASS_NAME = AMQP
VERSION = CLASS_NAME::VERSION

# Load rakefile tasks
Dir['tasks/*.rake'].sort.each { |file| load file }

desc "Generate AMQP specification classes"
task :codegen do
  sh 'ruby protocol/codegen.rb > lib/amqp/spec.rb'
  sh 'ruby lib/amqp/spec.rb'
end

desc "Run test suite (uses bacon gem)"
task :test do
  sh 'bacon lib/amqp.rb'
end
