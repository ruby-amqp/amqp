#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Auxiliary script that tests automatically recovering message consumer(s)"
puts
AMQP.start(:host => "localhost") do |connection, open_ok|
  connection.on_error do |ch, connection_close|
    raise connection_close.reply_text
  end

  ch1 = AMQP::Channel.new(connection, 2)
  ch1.on_error do |ch, channel_close|
    raise channel_close.reply_text
  end


  exchange = ch1.fanout("amq.fanout", :durable => true)
  EventMachine.add_periodic_timer(0.5) do
    puts "Publishing..."
    # messages must be routable & there must be at least one consumer.
    exchange.publish("Hello", :immediate => true, :mandatory => true)
  end


  show_stopper = Proc.new {
    connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
  }

  Signal.trap "TERM", show_stopper
  Signal.trap "INT",  show_stopper
  EM.add_timer(15, show_stopper)

  puts "This example a helper that publishes messages to amq.fanout. Use together with examples/error_handling/automatically_recovering_hello_world_consumer.rb."
  puts "This example terminates in 15 seconds and needs MANUAL RESTART when connection fails"
end
