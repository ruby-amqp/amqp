#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a queue with server-generated name using AMQP::Queue constructor
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  AMQP::Queue.new(channel, "", :auto_delete => true) do |queue|
    puts "#{queue.name} is ready to go."

    connection.close {
      EventMachine.stop { exit }
    }
  end
end
