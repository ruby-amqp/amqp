#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'
require 'pp'

AMQP.start do |connection|
  channel  = AMQP::Channel.new(connection)
  exchange = AMQP::Exchange.default

  queue_name = 'awesome'
  queue      = channel.queue(queue_name)

  exchange.publish('Totally rad 1', :routing_key => queue_name)
  exchange.publish('Totally rad 2', :routing_key => queue_name)

  EM.add_periodic_timer(1.5) { exchange.publish("Published at #{Time.now.to_i * 1000}", :routing_key => queue_name) }


  pop_handler = Proc.new { |headers, payload|
    unless msg
      # queue was empty
      p [Time.now, "queue is empty"]

      # try again in 1 second
      EM.add_timer(1) { queue.pop }
    else
      # process this message
      p [Time.now, payload, headers.delivery_tag, headers.redelivered, headers.exchange, headers.routing_key]

      # get the next message in the queue
      queue.pop
    end
  }

  10.times { queue.pop(&pop_handler) }

  EM.add_periodic_timer(1) do
    queue.pop(&pop_handler)
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    # now change this to just EM.stop and it
    # unbinds instantly
    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(6, show_stopper)
end
