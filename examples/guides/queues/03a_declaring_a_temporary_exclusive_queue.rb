#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a temporary exclusive queue
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)

  AMQP::Queue.new(channel, "", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    puts "#{queue.name} is ready to go."

    connection.close {
      EventMachine.stop { exit }
    }
  end
end
