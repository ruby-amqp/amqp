#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))
require 'amqp'


AMQP.start do |connection|
  puts "Connected!"
  channel = AMQP::Channel.new(connection)
  e       = channel.fanout("amqp-gem.examples.ack")
  q       = channel.queue('amqp-gem.examples.q1').bind(e) { puts "Bound #{e.name} to the queue" }

  q.status do |message_count, consumer_count|
    puts "Queue #{q.name} has #{message_count} messages and #{consumer_count} consumers"
  end

  i = 0

  # Stopping after the second item was acked will keep the 3rd item in the queue
  q.subscribe(:ack => true) do |h, m|
    puts "Got a message"

    if AMQP.closing?
      puts "#{m} (ignored, redelivered later)"
    else
      puts m
      h.ack
    end
  end # channel.queue


  10.times do |i|
    puts "Publishing message ##{i}"
    e.publish("Totally rad #{i}")
  end


  show_stopper = Proc.new {
    q.status do |message_count, consumer_count|
      puts "Queue #{q.name} has #{message_count} messages and #{consumer_count} consumers"
    end

    q.unbind(e) do
      puts "Unbound #{q.name} from #{e.name}"

      e.delete do
        puts "Just deleted #{e.name}"
      end

      q.delete do
        puts "Just deleted #{q.name}"
        AMQP.stop do
          puts "About to stop EM reactor"
          EM.stop
        end
      end
    end
  }

  EM.add_timer(3, show_stopper)

  # For ack to work appropriately you must shutdown AMQP gracefully,
  # otherwise all items in your queue will be returned
  Signal.trap('INT',  show_stopper)
  Signal.trap('TERM', show_stopper)
end # AMQP.start
