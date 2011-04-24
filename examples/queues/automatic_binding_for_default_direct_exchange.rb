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

puts "=> Default exchange example"
puts
AMQP.start(:host => 'localhost') do |connection|
  ch        = AMQP::Channel.new(connection)

  queue1    = ch.queue("queue1").subscribe do |payload|
    puts "[#{queue1.name}] => #{payload}"
  end
  queue2    = ch.queue("queue2").subscribe do |payload|
    puts "[#{queue2.name}] => #{payload}"
  end
  queue3    = ch.queue("queue3").subscribe do |payload|
    puts "[#{queue3.name}] => #{payload}"
  end
  queues    = [queue1, queue2, queue3]

  # Rely on default direct exchange binding, see section 2.1.2.4 Automatic Mode in AMQP 0.9.1 spec.
  exchange = AMQP::Exchange.default
  EM.add_periodic_timer(1) do
    q = queues.sample

    $stdout.puts "Publishing to default exchange with routing key = #{q.name}..."
    exchange.publish "Some payload from #{Time.now.to_i}", :routing_key => q.name
  end


  show_stopper = Proc.new do
    queue1.delete
    queue2.delete
    queue3.delete

    $stdout.puts "Stopping..."
    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT",  &show_stopper
  Signal.trap "TERM", &show_stopper
  EM.add_timer(7, show_stopper)
end
