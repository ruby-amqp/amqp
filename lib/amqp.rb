# encoding: utf-8

require "amq/protocol"

require "amqp/version"
if RUBY_VERSION =~ /^1.8.7/
  require "amqp/compatibility/ruby187_patchlevel_check"
end

require "amqp/handlers_registry"
require "amqp/callbacks"
require "amqp/entity"

require "amqp/exceptions"
require "amqp/session"
require "amqp/connection"
require "amqp/exchange"
require "amqp/queue"
require "amqp/channel"
require "amqp/header"
