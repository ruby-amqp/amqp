#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a durable shared queue
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  queue   = AMQP::Queue.new(channel, "images.resize", :durable => true)

  connection.close {
    EventMachine.stop { exit }
  }
end
