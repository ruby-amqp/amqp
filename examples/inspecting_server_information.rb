#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  AMQP.connect(:host => '127.0.0.1') do |connection|
    puts "Server properties:"
    puts
    puts connection.server_properties.inspect

    puts "Server capabilities:"
    puts
    puts connection.server_capabilities.inspect

    puts "Broker product: #{connection.broker_product}, version: #{connection.broker_version}"
    puts "Connected to RabbitMQ? #{connection.with_rabbitmq?}"

    connection.disconnect { EventMachine.stop }
  end # AMQP.connect
end # EventMachine.run
