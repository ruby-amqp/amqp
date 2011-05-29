#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  puts "Connected"
  AMQP::Channel.new(connection) do |channel, open_ok|
    puts "Opened a channel"
    channel.on_error do |ch, channel_close|
      raise "Channel-level exception: #{channel_close.reply_text}"
    end
    exchange = channel.fanout("amq.fanout")

    channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
      EventMachine.add_timer(0.5) do
        queue.delete do
          puts "Deleted #{queue.name}"
          connection.close {
            EM.stop { exit }
          }
        end
      end # EventMachine.add_timer
    end # channel.queue
  end
end
