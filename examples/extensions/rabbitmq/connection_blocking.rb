#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../../lib", __FILE__))
require 'amqp'
require "amqp/extensions/rabbitmq"

puts "=> Demonstrating connection.blocked"
puts

# This example requires high memory watermark to be set
# really low to demonstrate blocking.
#
# rabbitmqctl set_vm_memory_high_watermark 0.00000001
#
# should do it.

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')

  connection.on_blocked do |conn, conn_blocked|
    puts "Connection blocked, reason: #{conn_blocked.reason}"
  end

  connection.on_unblocked do |conn, _|
    puts "Connection unblocked"
  end

  puts "Connecting to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

  AMQP::Channel.new(connection) do |ch|
    x  = ch.default_exchange

    puts "Publishing..."
    x.publish("z" * 1024 * 1024 * 24)
  end

  show_stopper = Proc.new {
    connection.close { EventMachine.stop }
  }

  EM.add_timer(120, show_stopper)
  Signal.trap('INT',  show_stopper)
  Signal.trap('TERM', show_stopper)
end
