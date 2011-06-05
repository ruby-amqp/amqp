#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Binding a queue to an exchange
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange) do |bind_ok|
      puts "Just bound #{queue.name} to #{exchange.name}"
    end

    connection.close {
      EventMachine.stop { exit }
    }
  end
end
