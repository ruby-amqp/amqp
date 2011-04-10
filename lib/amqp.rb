# encoding: utf-8

require "amq/client"
require "amq/client/adapters/event_machine"

require "amqp/version"
require "amqp/exceptions"
require "amqp/connection"
require "amqp/exchange"
require "amqp/queue"
require "amqp/channel"
require "amqp/header"


# Will be removed before 1.0.

require "amqp/deprecated/mq"
require "amqp/deprecated/rpc"
require "amqp/deprecated/fork"