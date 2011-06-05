#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange)
    puts "Bound. Publishing a message..."
    exchange.publish("Ohai!")

    EventMachine.add_timer(0.5) do
      queue.pop do |metadata, payload|
        if payload
          puts "Fetched a message: #{payload.inspect}, content_type: #{metadata.content_type}. Shutting down..."
        else
          puts "No messages in the queue"
        end

        connection.close { EventMachine.stop }
      end
    end
  end
end
