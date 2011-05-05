#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672/") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    exchange = channel.fanout("amq.fanout")

    channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
      queue.bind(exchange).subscribe do |headers, payload|
        puts "Received a new message"
      end

      EventMachine.add_timer(0.3) do
        queue.unsubscribe
        puts "Unsubscribed. Shutting down..."

        connection.close {
          EM.stop { exit }
        }
      end # EventMachine.add_timer
    end # channel.queue
  end
end
