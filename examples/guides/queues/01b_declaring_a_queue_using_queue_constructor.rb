#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a queue with explicitly given name using AMQP::Queue constructor
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    AMQP::Queue.new(channel, "images.resize", :auto_delete => true) do |queue, declare_ok|
      puts "#{queue.name} is ready to go."

      connection.close {
        EventMachine.stop { exit }
      }
    end
  end
end
