$stdout.puts <<-MESSAGE
-------------------------------------------------------------------------------------
DEPRECATION WARNING!

Use of amqp/rpc.rb is deprecated. Instead of

  require "amqp/rpc"

please use

  require "amqp/deprecated/rpc"


Both amqp/rpc.rb and AMQP::RPC implementation will be REMOVED before 1.0 release.
MESSAGE

require "amqp/deprecated/rpc"
