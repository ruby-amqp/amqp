#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Handling a returned unroutable message that was published as mandatory"
puts

AMQP.start(:host => '127.0.0.1') do |connection|
  channel  = AMQP.channel
  channel.on_error { |ch, channel_close| EventMachine.stop; raise "channel error: #{channel_close.reply_text}" }

  # this exchange has no bindings, so messages published to it cannot be routed.
  exchange = channel.fanout("amqpgem.examples.fanout", :auto_delete => true)
  exchange.on_return do |basic_return, metadata, payload|
    puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
  end

  EventMachine.add_timer(0.3) {
    10.times do |i|
      exchange.publish("Message ##{i}", :mandatory => true)
    end
  }

  EventMachine.add_timer(2) {
    connection.close { EventMachine.stop }
  }
end
