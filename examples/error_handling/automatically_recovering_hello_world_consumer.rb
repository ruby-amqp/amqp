#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Example of automatic AMQP channel and queues recovery"
puts
AMQP.start(:host => "localhost") do |connection, open_ok|
  connection.on_error do |ch, connection_close|
    raise connection_close.reply_text
  end

  ch1 = AMQP::Channel.new(connection, 2, :auto_recovery => true)
  ch1.on_error do |ch, channel_close|
    raise channel_close.reply_text
  end

  connection.on_tcp_connection_loss do |conn, settings|
    puts "[network failure] Trying to reconnect..."
    conn.reconnect(false, 2)
  end

  queue = ch1.queue("amqpgem.examples.queue3", :auto_delete => false, :durable => true).bind("amq.fanout").subscribe do |metadata, payload|
    puts "[consumer1] => #{payload}"
  end
  consumer2 = AMQP::Consumer.new(ch1, queue)
  consumer2.consume.on_delivery do |metadata, payload|
    puts "[conusmer2] => #{payload}"
  end


  show_stopper = Proc.new {
    connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
  }

  Signal.trap "TERM", show_stopper
  Signal.trap "INT",  show_stopper
  EM.add_timer(45, show_stopper)


  puts "Connected, authenticated. To really exercise this example, shut AMQP broker down for a few seconds. If you don't it will exit gracefully in 45 seconds."
end
