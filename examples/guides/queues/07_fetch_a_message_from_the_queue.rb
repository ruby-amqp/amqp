#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    exchange = channel.fanout("amq.fanout")

    channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
      queue.bind(exchange) do |_|
        puts "Bound. Publishing a message..."
        exchange.publish("Ohai!")
      end

      EventMachine.add_timer(0.5) do
        queue.pop do |response|
          puts "Fetched a message: #{response.inspect}. Shutting down..."

          connection.close {
            EM.stop { exit }
          }
        end
      end
    end
  end
end
