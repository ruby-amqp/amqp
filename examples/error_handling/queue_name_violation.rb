#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue declaration uses name prefix amq.* reserved by the AMQP spec"
puts
AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    channel.on_error do |ch, close|
      puts "Handling a channel-level exception: #{close.reply_text}, code: #{close.reply_code}"
    end

    channel.queue("amq.queue")
  end


  EventMachine.add_timer(0.5) do
    connection.close {
      EventMachine.stop { exit }
    }
  end
end
