#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  AMQP.connect(:host => '127.0.0.1') do |connection|
    puts
    puts "Connected to #{connection.hostname}:#{connection.port}/#{connection.vhost}"
    puts
    puts "Client properties:"
    puts
    puts connection.client_properties.inspect

    puts "Server properties:"
    puts
    puts connection.server_properties.inspect

    puts "Server capabilities:"
    puts
    puts connection.server_capabilities.inspect

    puts "Broker product: #{connection.broker.product}, version: #{connection.broker.version}"
    puts "Connected to RabbitMQ? #{connection.broker.rabbitmq?}"

    puts
    puts "Broker supports publisher confirms? #{connection.broker.supports_publisher_confirmations?}"

    puts
    puts "Broker supports basic.nack? #{connection.broker.supports_basic_nack?}"

    puts
    puts "Broker supports consumer cancel notifications? #{connection.broker.supports_consumer_cancel_notifications?}"

    puts
    puts "Broker supports exchange-to-exchange bindings? #{connection.broker.supports_exchange_to_exchange_bindings?}"

    connection.disconnect { EventMachine.stop }
  end # AMQP.connect
end # EventMachine.run
