#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue redeclaration with different attributes results in a channel exception that is handled by a global callback we carry from 0.7.x days"
puts

puts <<-MSG
WARNING!! ACHTUNG!! AVIS!! AVISO!! Poorly designed API use ahead!!

Please never ever use global error handler demonstrated below!
It is a brilliant decision from early days of the library and we have to carry it
along for backwards compatibility.

Global state is programming is usually a pain. Global error handling is a
true Hell.

You have been warned.
MSG

puts
puts

AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    channel.on_error do |ch, channel_close|
      puts "Handling channel-level exception at instance level"
    end

    AMQP::Channel.on_error do |ch, channel_close|
      puts "Handling channel-level exception at GLOBAL level. Jeez. Message is #{channel_close.reply_text}"
    end

    EventMachine.add_timer(0.4) do
      q1 = AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => false) do |queue|
        puts "#{queue.name} is ready to go"
      end

      q2 = AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => true) do |queue|
        puts "#{queue.name} is ready to go"
      end
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
