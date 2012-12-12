#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connected to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

  channel  = AMQP::Channel.new(connection)
  queue    = channel.queue("amqpgem.examples.helloworld", :auto_delete => true)
  exchange = channel.direct("")

  queue.subscribe do |payload|
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close {
      EM.stop { exit }
    }
  end

  exchange.publish "Hello, world!", :routing_key => queue.name
end
