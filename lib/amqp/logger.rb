# encoding: utf-8

$stdout.puts <<-MESSAGE
-------------------------------------------------------------------------------------
DEPRECATION WARNING!

Use of amqp/logger.rb is deprecated. Instead of

  require "amqp/logger"

please use

  require "amqp/deprecated/logger"


Both amqp/logger.rb and AMQP::Logger will be REMOVED before 1.0 release.
MESSAGE

require "amqp/deprecated/logger"
