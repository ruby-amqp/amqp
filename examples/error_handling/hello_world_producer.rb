#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Auxiliary script that tests automatically recovering message consumer(s)"
puts
AMQP.start(:host => ENV.fetch("BROKER_HOST", "localhost")) do |connection, open_ok|
  puts "Connected to #{connection.hostname}"
  connection.on_error do |ch, connection_close|
    raise connection_close.reply_text
  end

  connection.on_tcp_connection_loss do |conn, settings|
    puts "[network failure] Trying to reconnect..."
    conn.reconnect(false, 2)
  end


  ch1 = AMQP::Channel.new(connection, :auto_recovery => true)
  ch1.on_error do |ch, channel_close|
    raise channel_close.reply_text
  end


  exchange = ch1.fanout("amq.fanout", :durable => true)
  EventMachine.add_periodic_timer(0.9) do
    puts "Publishing via default exchange..."
    # messages must be routable & there must be at least one consumer.
    ch1.default_exchange.publish("Routed via default_exchange", :routing_key => "amqpgem.examples.autorecovery.queue")
  end

  EventMachine.add_periodic_timer(0.8) do
    puts "Publishing via amq.fanout..."
    # messages must be routable & there must be at least one consumer.
    exchange.publish("Routed via amq.fanout", :mandatory => true)
  end


  show_stopper = Proc.new {
    connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
  }

  Signal.trap "TERM", show_stopper
  Signal.trap "INT",  show_stopper
  EM.add_timer(ENV.fetch("TIMER", 15), show_stopper)

  puts "This example a helper that publishes messages to amq.fanout. Use together with examples/error_handling/automatically_recovering_hello_world_consumer.rb."
  puts "This example terminates in 15 seconds and needs MANUAL RESTART when connection fails"
end
