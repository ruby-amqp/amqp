#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue#initialize example that uses a block"
puts
AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!" if channel.open?

    xchange = channel.fanout("amq.fanout", :nowait => true)
    q = AMQP::Queue.new(channel, "", :auto_delete => true)


    EM.add_timer(0.5) do
      puts "Channel ##{channel.id} is still open!" if channel.open?
      q.bind(xchange).subscribe do |header, payload|
        puts "Got a payload: #{payload}"
      end

      EventMachine.add_timer(0.3) { xchange.publish("à bientôt!") }
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
