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

    channel.on_error do |ch, close|
      puts "close = #{close.inspect}"
      puts "Handling channel-level exception"
    end

    EventMachine.add_timer(0.4) do
      q = AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => false)

      q.unbind("amq.fanout")
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
