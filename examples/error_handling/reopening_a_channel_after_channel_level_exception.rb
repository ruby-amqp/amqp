#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue redeclaration with different attributes results in a channel exception that is handled"
puts
EventMachine.run do
  connection = AMQP.connect(:port => ENV.fetch("PORT", 5672))
  AMQP::Channel.new(connection) do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    connection.on_error do |conn, connection_close|
      puts <<-ERR
      Handling a connection-level exception:

      connection_close.reply_text: #{connection_close.reply_text}
      ERR
    end

    channel.on_error do |ch, channel_close|
      puts "Handling a channel-level exception: #{channel_close.reply_code} #{channel_close.reply_text}"
      ch.reuse
    end

    # initial operations that cause the channel-level exception handled above
    EventMachine.add_timer(0.5) do
      # these two definitions result in a race condition. For sake of this example,
      # however, it does not matter. Whatever definition succeeds first, 2nd one will
      # cause a channel-level exception (because attributes are not identical)
      AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :exclusive => true, :durable => false)
      AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => true)
    end

    EventMachine.add_timer(2.0) do
      puts "Resuming with reopened channel #{channel.id}"
      q = channel.queue("amqpgem.examples.channel_exception.q1", :exclusive => true).bind("amq.fanout").subscribe do |meta, payload|
        puts "Consumed #{payload}"
      end
    end

    EventMachine.add_periodic_timer(3.0) do
      puts "Publishing a message..."
      x = channel.fanout("amq.fanout")
      x.publish("xyz", :routing_key => "amqpgem.examples.channel_exception.q1")
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
