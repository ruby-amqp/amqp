#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Binding a queue to an exchange
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  exchange_name = "amq.fanout"

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange_name)
    puts "Bound #{queue.name} to #{exchange_name}"

    connection.close {
      EventMachine.stop { exit }
    }
  end
end
