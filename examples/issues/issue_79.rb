#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "Running amqp gem #{AMQP::VERSION}"



AMQP.start do |conn|
  @amqp_connection = conn

  AMQP::Channel.new(@amqp_connection) do |channel|
    @amqp_channel  = channel
    @amqp_exchange = @amqp_channel.topic

    AMQP::Queue.new(@amqp_channel, "") do |queue|
      queue.bind(@amqp_exchange, :routing_key => "a.*.pattern").subscribe(:ack => true) do |header, payload|
        p header.class
        p header.to_hash

        conn.close { EventMachine.stop }
      end
    end

    EventMachine.add_timer(0.3) do
      @amqp_exchange.publish "a message", :routing_key => "a.b.pattern"
    end
  end
end