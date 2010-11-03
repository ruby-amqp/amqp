require 'pathname'

module AMQP
  version_file = Pathname.new(__FILE__).dirname + '../VERSION'   # :nodoc:
  VERSION = version_file.exist? ? version_file.read.strip : '0.6.8'
end
