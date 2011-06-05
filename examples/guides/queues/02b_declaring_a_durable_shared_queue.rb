#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a durable shared queue using AMQP::Channel#queue method
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  queue   = channel.queue("images.resize", :durable => true)

  connection.close {
    EventMachine.stop { exit }
  }
end
