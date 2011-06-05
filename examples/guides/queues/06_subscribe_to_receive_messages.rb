#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue|
    queue.bind(exchange).subscribe do |metadata, payload|
      puts "Received a message: #{payload.inspect}. Shutting down..."

      connection.close { EventMachine.stop }
    end

    EventMachine.add_timer(0.2) do
      puts "=> Publishing..."
      exchange.publish("Ohai!")
    end
  end
end
