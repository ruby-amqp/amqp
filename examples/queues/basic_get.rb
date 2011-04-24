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


puts "=> basic.get example"
puts
AMQP.start(:host => 'localhost') do |connection|
  channel   = AMQP::Channel.new
  
  queue_name = "amqpgem.integration.basic.get.queue"
  expected_number_of_messages = 50
  
  exchange = channel.fanout("amqpgem.integration.basic.get.fanout", :auto_delete => true)
  queue    = channel.queue(queue_name, :auto_delete => true)
  
  queue.bind(exchange) do
    puts "Bound #{exchange.name} => #{queue.name}"
  end
  expected_number_of_messages.times do |i|
    print "."
    exchange.publish(Time.now.to_i.to_s + "_#{i}", :key => queue_name)
  end
  $stdout.flush

  sleep 1

  queue.status do |number_of_messages, number_of_consumers|
    puts "# of messages on status = #{number_of_messages}"
  end

  queue.status do |number_of_messages, number_of_consumers|
    puts "# of messages on status = #{number_of_messages}"
    expected_number_of_messages.times do
      queue.pop do |headers, payload|
        puts "=> With payload #{payload.inspect}, routing key: #{headers.routing_key}, #{headers.message_count} message(s) left in the queue"
      end # pop
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(2, show_stopper)
end
