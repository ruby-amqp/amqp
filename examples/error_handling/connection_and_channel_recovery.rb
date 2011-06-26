#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


class ConnectionInterruptionHandler

  #
  # API
  #

  def handle(connection)
    puts "Connection #{connection} detected connection interruption"
  end

end


puts "=> Example of AMQP connection & channel recovery API in action"
puts
AMQP.start(:host => "localhost") do |connection, open_ok|
  unless connection.auto_recovering?
    puts "Connection IS NOT auto-recovering..."
  end

  ch1 = AMQP::Channel.new(connection)
  ch1.on_error do |ch, channel_close|
    raise channel_close.reply_text
  end

  unless ch1.auto_recovering?
    puts "Channel #{ch1.id} IS NOT auto-recovering"
  end
  ch1.on_connection_interruption do |c|
    puts "Channel #{c.id} reacted to connection interruption"
  end


  connection.on_tcp_connection_loss do |conn, settings|
    puts "Trying to reconnect..."
    conn.reconnect(false, 2)
  end


  handler = ConnectionInterruptionHandler.new
  connection.on_connection_interruption(&handler.method(:handle))

  connection.on_recovery do |conn, settings|
    puts "Connection recovered"
  end

  show_stopper = Proc.new {
    connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
  }

  Signal.trap "TERM", show_stopper
  Signal.trap "INT",  show_stopper
  EM.add_timer(30, show_stopper)


  puts "Connected, authenticated. To really exercise this example, shut AMQP broker down for a few seconds. If you don't it will exit gracefully in 30 seconds."
end
