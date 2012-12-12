#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Example of automatic AMQP channel and queues recovery"
puts
AMQP.start(:host => ENV.fetch("BROKER_HOST", "localhost")) do |connection, open_ok|
  connection.on_error do |ch, connection_close|
    raise connection_close.reply_text
  end

  ch1 = AMQP::Channel.new(connection, :auto_recovery => true)
  ch1.on_error do |ch, channel_close|
    raise channel_close.reply_text
  end

  connection.on_tcp_connection_loss do |conn, settings|
    puts "[network failure] Trying to reconnect..."
    conn.reconnect(false, 2)
  end

  queue = ch1.queue("amqpgem.examples.autorecovery.queue", :auto_delete => false, :durable => true).bind("amq.fanout")
  queue.subscribe(:ack => true) do |metadata, payload|
    puts "[consumer1] => #{payload}"
    metadata.ack
  end
  consumer2 = AMQP::Consumer.new(ch1, queue)
  consumer2.consume.on_delivery do |metadata, payload|
    puts "[conusmer2] => #{payload}"
    metadata.ack
  end


  show_stopper = Proc.new {
    connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
  }

  Signal.trap "TERM", show_stopper
  Signal.trap "INT",  show_stopper
  EM.add_timer(ENV.fetch("TIMER", 45), show_stopper)


  puts "This example needs another script/app to publish messages to amq.fanout. See examples/error_handling/hello_world_producer.rb for example"
  puts "Connected, authenticated. To really exercise this example, shut RabbitMQ down for a few seconds. If you don't it will exit gracefully in 45 seconds."
end
