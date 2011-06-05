#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange).subscribe do |headers, payload|
      puts "Received a new message"
    end

    EventMachine.add_timer(0.3) do
      queue.unsubscribe
      puts "Unsubscribed. Shutting down..."

      connection.close { EventMachine.stop }
    end # EventMachine.add_timer
  end # channel.queue
end
