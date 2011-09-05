#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue redeclaration with different attributes results in a channel exception that is handled"
puts
EventMachine.run do
  connection = AMQP.connect
  AMQP::Channel.new(connection, :auto_recovery => true) do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    connection.on_error do |conn, connection_close|
      puts <<-ERR
      Handling a connection-level exception:

      connection_close.reply_text: #{connection_close.reply_text}
      ERR
    end

    channel.on_error do |ch, channel_close|
      puts <<-ERR
      Handling a channel-level exception.

      AMQP class id : #{channel_close.class_id},
      AMQP method id: #{channel_close.method_id},
      Status code   : #{channel_close.reply_code}
      Error message : #{channel_close.reply_text}
      ERR

      puts "Reusing channel #{ch.id}"
      ch.reuse
      puts "Channel id is now #{ch.id}"
    end

    EventMachine.add_timer(1.0) do
      # these two definitions result in a race condition. For sake of this example,
      # however, it does not matter. Whatever definition succeeds first, 2nd one will
      # cause a channel-level exception (because attributes are not identical)
      AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => false) do |queue|
        puts "#{queue.name} is ready to go"
      end

      AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => true) do |queue|
        puts "#{queue.name} is ready to go"
      end
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."

    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  # EM.add_timer(2, show_stopper)
end
