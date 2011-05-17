#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://dev.rabbitmq.com:5672") do |connection|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.fanout("nba.scores")

  channel.queue("joe", :auto_delete => true).bind(exchange).subscribe do |payload|
    puts "#{payload} => joe"
  end

  channel.queue("aaron", :auto_delete => true).bind(exchange).subscribe do |payload|
    puts "#{payload} => aaron"
  end

  channel.queue("bob", :auto_delete => true).bind(exchange).subscribe do |payload|
    puts "#{payload} => bob"
  end

  exchange.publish("BOS 101, NYK 89").publish("ORL 85, ALT 88")

  # disconnect & exit after 2 seconds
  EventMachine.add_timer(2) do
    exchange.delete

    connection.close {
      EM.stop { exit }
    }
  end
end
