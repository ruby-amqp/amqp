#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Example of basic failover with AMQP::Session#reconnect_to"
puts
AMQP.start(:host => "localhost") do |connection, open_ok|
  connection.on_recovery do |conn, settings|
    puts "Connection recovered, now connected to dev.rabbitmq.com"
  end

  connection.on_tcp_connection_loss do |conn, settings|
    puts "Trying to reconnect..."
    conn.reconnect_to("amqp://dev.rabbitmq.com")
  end
end
