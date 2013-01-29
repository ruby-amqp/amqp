#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'amqp'

t = Thread.new { EventMachine.run }
if defined?(JRUBY_VERSION)
  # on the JVM, event loop startup takes longer and .next_tick behavior
  # seem to be a bit different. Blocking current thread for a moment helps.
  sleep 0.5
end

EventMachine.next_tick {
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connected to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

  channel  = AMQP::Channel.new(connection)
  queue    = channel.queue("amqpgem.examples.hello_world", :auto_delete => true)
  exchange = channel.direct("")

  queue.subscribe do |payload|
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close {
      EM.stop { exit }
    }
  end

  exchange.publish "Hello, world!", :routing_key => queue.name
}

t.join
