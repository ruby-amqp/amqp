#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  channel.on_error do |ch, channel_close|
    raise "Channel-level exception: #{channel_close.reply_text}"
  end
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.purge do |_|
      puts "Purged #{queue.name}"
    end

    EventMachine.add_timer(0.5) do
      connection.close { EventMachine.stop }
    end # EventMachine.add_timer
  end # channel.queue
end
