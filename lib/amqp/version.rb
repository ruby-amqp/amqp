require 'pathname'

module AMQP
  VERSION_FILE = Pathname.new(__FILE__).dirname + '../../VERSION'   # :nodoc:
  VERSION = VERSION_FILE.exist? ? VERSION_FILE.read.strip : '0.6.8'
end
