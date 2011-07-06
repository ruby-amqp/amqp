#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Queue#status example"
puts
AMQP.start(:host => 'localhost') do |connection|
  channel   = AMQP::Channel.new(connection)

  queue_name = "amqpgem.integration.queue.status.queue"
  exchange   = channel.fanout("amqpgem.integration.queue.status.fanout", :auto_delete => true)
  queue      = channel.queue(queue_name, :auto_delete => true).bind(exchange)

  100.times do |i|
    print "."
    exchange.publish(Time.now.to_i.to_s + "_#{i}", :key => queue_name)
  end
  $stdout.flush

  EventMachine.add_timer(0.5) do
    queue.status do |number_of_messages, number_of_consumers|
      puts
      puts "# of messages on status = #{number_of_messages}"
      puts
      queue.purge
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close { EventMachine.stop }
  end

  Signal.trap "INT", show_stopper
  EventMachine.add_timer(2, show_stopper)
end
