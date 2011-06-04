#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a queue with explicitly given name using AMQP::Queue constructor
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  queue   = AMQP::Queue.new(channel, "images.resize", :auto_delete => true)

  puts "#{queue.name} is ready to go."

  connection.close {
    EventMachine.stop { exit }
  }
end
