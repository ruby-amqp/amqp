#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672/") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    exchange = channel.fanout("amq.fanout")

    channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
      queue.bind(exchange).subscribe do |headers, payload|
        puts "Received a message: #{payload.inspect}. Shutting down..."

        connection.close {
          EM.stop { exit }
        }
      end

      EventMachine.add_timer(0.2) do
        exchange.publish("Ohai!")
      end
    end
  end
end
