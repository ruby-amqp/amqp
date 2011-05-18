#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

# CODE BELOW IS USING DEPRECATED METHODS. PLEASE CONSIDER NOT USING THEM IF YOU CAN.
#
# The reason why these methods work at all is to make 0.6.x => 0.8.x migration easier so
# people won't be stuck with AMQP (the protocol) 0.8 forever and can benefit from more
# advanced AMQP 0.9.1 features.
#

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."

  queue    = AMQP::Channel.queue("amqpgem.examples.hello_world", :auto_delete => true)
  exchange = MQ.direct("")

  queue.subscribe do |payload|
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close {
      EM.stop { exit }
    }
  end

  exchange.publish "Hello, world!", :routing_key => queue.name
end
