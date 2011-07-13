#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Publishing and immediately stopping the event loop in the callback"
puts

# WARNING: this example is born out of http://bit.ly/j6v1Uz (#67) and
#          by no means a demonstration of how you should go about publishing one-off messages.
#          If durability is a concern, please read our "Durability and message persistence" guide at
#          http://bit.ly/lQP1Al

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  channel    = AMQP::Channel.new(connection)
  channel.on_error do |ch, channel_close|
    puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
    connection.close { EventMachine.stop }
  end

  # topic exchange is used just as example. Often it is more convenient to use default exchange,
  # see http://bit.ly/amqp-gem-default-exchange
  exchange = channel.topic("a.topic", :durable => true, :auto_delete => true)
  queue    = channel.queue("a.queue", :auto_delete => true).bind(exchange, :routing_key => "events.#")

  exchange.publish('hello world', :routing_key => "events.hits.homepage", :persistent => true, :nowait => false) do
    puts "About to disconnect..."
    connection.close { EventMachine.stop }
  end
end
