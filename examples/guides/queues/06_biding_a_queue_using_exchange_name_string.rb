#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Binding a queue to an exchange
AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672/") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    exchange_name = "amq.fanout"

    channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
      queue.bind(exchange_name) do |bind_ok|
        puts "Just bound #{queue.name} to #{exchange_name}"
      end

      connection.close {
        EM.stop { exit }
      }
    end
  end
end
