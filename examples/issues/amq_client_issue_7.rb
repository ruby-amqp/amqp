#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "Running amqp gem #{AMQP::VERSION}"

EM.run do 

  AMQP.connect do |conn|
    @amqp_connection = conn

    AMQP::Channel.new(@amqp_connection) do |channel|
      @amqp_channel  = channel
      @amqp_exchange = @amqp_channel.topic

      EventMachine.add_periodic_timer(0) do
        random_binary_string = Array.new(rand(1000)) { rand(256) }.pack('c*')
        random_binary_string.force_encoding('BINARY')
        p random_binary_string
        @amqp_exchange.publish(random_binary_string, :routing_key => "a.my.pattern")
      end
    end
  end

end
