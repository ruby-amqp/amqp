#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Using a callback to #publish. It is run on the _next_ EventMachine loop run."
puts

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  channel    = AMQP::Channel.new(connection)
  channel.on_error do |ch, channel_close|
    puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
    connection.close { EventMachine.stop }
  end

  queue    = channel.queue("amqpgem.examples.publishing.queue1", :auto_delete => true)
  exchange = channel.fanout("amqpgem.examples.topic", :durable => true, :auto_delete => true)

  queue.bind(exchange, :routing_key => "some_topic")


  # Don't be deceived: this callback is run on the next event loop tick. There is no guarantee that your
  # data was sent: there is buffering going on on multiple layers (C++ core of EventMachine, libc functions,
  # kernel uses buffering for many I/O system calls).
  #
  # This callback is simply for convenience. In a distributed environment, the only way to know when your data
  # is sent is when you receive an acknowledgement. TCP works that way. MK.

  100.times do |i|
    exchange.publish("hello world #{i}", :routing_key => "some_topic", :persistent => true) do
      puts "Callback #{i} has fired"
    end
  end

  exchange.publish("hello world 101", :routing_key => "some_topic", :persistent => false) do
    puts "Callback 101 has fired"
  end

  exchange.publish("hello world 102", :routing_key => "some_topic", :persistent => true) do
    puts "Callback 102 has fired"
  end

  EventMachine.add_timer(1) do
    connection.close { EventMachine.stop }
  end
end
