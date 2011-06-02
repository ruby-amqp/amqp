#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

if RUBY_VERSION == "1.8.7"
  class Array
    alias sample choice
  end
end


puts "=> Queue#status example"
puts
AMQP.start(:host => 'localhost') do |connection|
  channel   = AMQP::Channel.new(connection)

  exchange = channel.fanout("amqpgem.integration.queue.status.fanout", :auto_delete => true)
  queue    = channel.queue("amqpgem.integration.queue.status.queue", :auto_delete => true)

  queue.bind(exchange).subscribe do |metadata, payload|
    puts "Rejecting #{payload}"
    channel.reject(metadata.delivery_tag)
  end

  100.times do |i|
    print "."
    exchange.publish(Time.now.to_i.to_s + "_#{i}", :key => queue.name)
  end
  $stdout.flush


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close {
      EventMachine.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EventMachine.add_timer(2, show_stopper)
end
