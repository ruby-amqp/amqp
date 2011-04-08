#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  AMQP.connect(:host => 'localhost') do |connection|
    puts "Connected to AMQP broker"

    channel  = AMQP::Channel.new(connection)
    queue    = channel.queue("amqpgem.examples.hello_world")
    exchange = channel.default_exchange

    queue.subscribe do |payload|
      puts "Received a message: #{payload}. Disconnecting..."

      connection.close {
        EM.stop { exit }
      }
    end

    exchange.publish "Hello, world!", :routing_key => queue.name
  end  
end
