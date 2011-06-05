#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  channel.on_error do |ch, channel_close|
    raise "Channel-level exception: #{channel_close.reply_text}"
  end

  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange)

    EventMachine.add_timer(0.5) do
      queue.unbind(exchange) do |_|
        puts "Unbound. Shutting down..."

        connection.close { EventMachine.stop }
      end
    end # EventMachine.add_timer
  end # channel.queue
end
