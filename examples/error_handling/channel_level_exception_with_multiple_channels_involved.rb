#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue redeclaration with different attributes results in a channel exception that is handled"
puts
AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  ch1 = AMQP::Channel.new(connection) do |ch, open_ok|
    puts "Channel ##{ch.id} is now open!"
  end
  ch1.on_error do |ch, close|
    raise "Handling channel-level exception on channel with id of #{ch.id} (ch1)"
  end

  ch2 = AMQP::Channel.new(connection) do |ch, open_ok|
    puts "Channel ##{ch.id} is now open!"
  end
  ch2.on_error do |ch, close|
    puts "close: #{close.inspect}"
    puts "Handling channel-level exception on channel with id of #{ch.id} (ch2)"
  end


  EventMachine.add_timer(0.2) do
    AMQP::Queue.new(ch1, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => false) do |queue|
      puts "#{queue.name} is ready to go"
    end
  end

  EventMachine.add_timer(0.6) do
    AMQP::Queue.new(ch2, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => true) do |queue|
      puts "#{queue.name} is ready to go"
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
