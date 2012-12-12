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

  if ch1.auto_recovering?
    puts "Channel #{ch1.id} IS auto-recovering"
  end

  connection.on_tcp_connection_loss do |conn, settings|
    puts "[network failure] Trying to reconnect..."
    conn.reconnect(false, 2)
  end


  ch1.queue("amqpgem.examples.queue1", :auto_delete => true).bind("amq.fanout")
  ch1.queue("amqpgem.examples.queue2", :auto_delete => true).bind("amq.fanout")
  ch1.queue("amqpgem.examples.queue3", :auto_delete => true).bind("amq.fanout").subscribe do |metadata, payload|
  end


  show_stopper = Proc.new {
    connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
  }

  Signal.trap "TERM", show_stopper
  Signal.trap "INT",  show_stopper
  EM.add_timer(30, show_stopper)


  puts "Connected, authenticated. To really exercise this example, shut RabbitMQ down for a few seconds. If you don't it will exit gracefully in 30 seconds."
end
