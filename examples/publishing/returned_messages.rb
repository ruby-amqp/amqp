#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Handling returned messages"
puts

AMQP.start(:host => '127.0.0.1') do |connection|
  channel  = AMQP.channel
  channel.on_error { |ch, channel_close| EventMachine.stop; raise "channel error: #{channel_close.reply_text}" }

  exchange = channel.fanout("amq.fanout")
  exchange.on_return do |basic_return, metadata, payload|
    puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
  end

  EventMachine.add_timer(0.3) {
    10.times do |i|
      exchange.publish("Message ##{i}")
    end
  }

  EventMachine.add_timer(2) {
    connection.close { EventMachine.stop }
  }
end
