#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

if RUBY_VERSION == "1.8.7"
  class Array
    alias sample choice
  end
end

puts "=> Publishing and immediately stopping the event loop in the callback"
puts

# WARNING: this example is born out of http://bit.ly/j6v1Uz (#67) and
#          by no means a demonstration of how you should go about publishing one-off messages.
#          If durability is a concern, please read our "Durability and message persistence" guide at
#          http://bit.ly/lQP1Al

EventMachine.run do
  client   = AMQP.connect(:host => '127.0.0.1')
  channel  = AMQP::Channel.new(client)
  channel.on_error { puts 'channel error'; EM.stop }

  queue    = channel.queue("some_topic", :auto_delete => true)
  exchange = channel.topic("foo", :durable => true, :auto_delete => true)

  exchange.publish( 'hello world', :routing_key => "some_topic", :persistent => true, :nowait => false ) do
    puts 'enqueued message for publishing on next event loop tick'
    EventMachine.stop
  end
end
