#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'
require 'pp'

AMQP.start(:host => 'localhost', :logging => false) do |connection|
  # open a channel on the AMQP connection
  channel = AMQP::Channel.new(connection)

  # declare a queue on the channel
  queue = AMQP::Channel::Queue.new(channel, 'queue name')

  # create a fanout exchange
  exchange = AMQP::Channel::Exchange.new(channel, :fanout, 'all queues')

  # bind the queue to the exchange
  queue.bind(exchange)

  # publish a message to the exchange
  exchange.publish('hello world')

  # subscribe to messages in the queue
  queue.subscribe do |headers, msg|
    pp [:got, headers, msg]
    connection.close { EM.stop_event_loop }
  end
end
