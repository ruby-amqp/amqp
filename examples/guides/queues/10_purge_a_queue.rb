#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  puts "Connected"
  AMQP::Channel.new(connection) do |channel, open_ok|
    puts "Opened a channel"
    channel.on_error do |arg|
      raise "Channel-level exception: #{arg.inspect}"
    end
    exchange = channel.fanout("amq.fanout")

    channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
      queue.purge do |_|
        puts "Purged #{queue.name}"
      end

      EventMachine.add_timer(0.5) do
        connection.close {
          EM.stop { exit }
        }
      end # EventMachine.add_timer
    end # channel.queue
  end
end
