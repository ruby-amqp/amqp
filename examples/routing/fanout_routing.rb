#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require "amqp"

EventMachine.run do
  AMQP.connect("amqp://dev.rabbitmq.com") do |connection|
    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic("amqpgem.examples.routing.fanout_routing", :auto_delete => true)

    # Subscribers.
    10.times do
      q = channel.queue("", :exclusive => true, :auto_delete => true).bind(exchange)
      q.subscribe do |payload|
        puts "Queue #{q.name} received #{payload}"
      end
    end

    # Publish some test data in a bit, after all queues are declared & bound
    EventMachine.add_timer(1.2) { exchange.publish "Hello, fanout exchanges world!" }


    show_stopper = Proc.new { connection.close { EventMachine.stop } }

    Signal.trap "TERM", show_stopper
    EM.add_timer(3, show_stopper)
  end
end
