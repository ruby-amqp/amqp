#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts
AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    channel.on_error do |ch, channel_close|
      puts "channel.close = #{channel_close.inspect}"
      puts "Handling a channel-level exception"
    end

    EventMachine.add_timer(0.4) do
      # this one works
      # binding = '12345678901234567890123456789012'

      # this one does not work
      binding = '123456789012345678901234567890123'
      queue   = channel.queue 'test', :auto_delete => true, :durable => false
      queue.bind('amq.topic', :routing_key => binding)
      queue.unbind('amq.topic', :routing_key => binding)
      queue.unbind('amq.topic', :routing_key => binding)
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."

    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(2, show_stopper)
end
