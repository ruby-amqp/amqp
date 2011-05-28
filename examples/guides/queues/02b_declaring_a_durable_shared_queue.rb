#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a durable shared queue using AMQP::Channel#queue method
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    channel.queue("images.resize", :durable => true) do |queue, declare_ok|
      puts "#{queue.name} is ready to go."

      connection.close {
        EventMachine.stop { exit }
      }
    end
  end
end
