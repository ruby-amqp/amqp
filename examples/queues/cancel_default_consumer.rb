#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connected to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

  channel  = AMQP::Channel.new(connection)
  queue    = channel.queue("amqpgem.examples.hello_world", :auto_delete => true)
  exchange = channel.direct("amq.direct")

  queue.bind(exchange, :routing_key => "amqpgem.key")

  channel.on_error do |ch, channel_close|
    puts channel_close.reply_text
    connection.close { EventMachine.stop }
  end

  queue.subscribe do |metadata, payload|
    puts "Received a message: #{payload}."
  end

  EventMachine.add_periodic_timer(1.0) do
    exchange.publish("Hey, what a great view!", :routing_key => "amqpgem.key")
  end

  EventMachine.add_timer(3.0) do
    queue.unsubscribe do
      puts "Cancelled default consumer..."
      connection.close { EventMachine.stop }
    end
  end
end
