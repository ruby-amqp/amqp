#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../../lib", __FILE__))
require 'amqp'
require "amqp/extensions/rabbitmq"

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connecting to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

  AMQP::Channel.new(connection) do |channel|
    puts "Channel #{channel.id} is now open"

    channel.confirm_select
    channel.on_error { |ch, channel_close| puts "Oops! a channel-level exception: #{channel_close.reply_text}" }
    channel.on_ack   { |basic_ack| puts "Received basic_ack: multiple = #{basic_ack.multiple}, delivery_tag = #{basic_ack.delivery_tag}" }

    x = channel.fanout("amq.fanout")
    channel.queue("", :auto_delete => true) do |q|
      q.bind(x).subscribe(:ack => true) do |header, payload|
        puts "Received #{payload}"
      end
    end

    EventMachine.add_timer(0.5) do
      10.times do |i|
        puts "Publishing message ##{i + 1}"
        x.publish("Message ##{i + 1}")
      end
    end
  end

  show_stopper = Proc.new {
    connection.close { EventMachine.stop }
  }

  EM.add_timer(6, show_stopper)
  Signal.trap('INT',  show_stopper)
  Signal.trap('TERM', show_stopper)
end
