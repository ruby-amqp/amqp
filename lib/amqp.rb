# encoding: utf-8

require "amq/protocol"
require "amq/client"
require "amq/client/adapters/event_machine"

require "amqp/version"
if RUBY_VERSION =~ /^1.8.7/
  require "amqp/compatibility/ruby187_patchlevel_check"
end

require "amqp/callbacks"
require "amqp/entity"

require "amqp/exceptions"
require "amqp/connection"
require "amqp/exchange"
require "amqp/queue"
require "amqp/channel"
require "amqp/header"
