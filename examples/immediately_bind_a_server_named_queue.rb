#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'amqp'


puts "=> AMQP gem #{AMQP::VERSION}"
puts
AMQP.start do |connection|
  channel = AMQP::Channel.new
  puts "Channel ##{channel.channel} is now open!"

  xchange = channel.fanout("amq.fanout")
  q = AMQP::Queue.new(channel, "", :auto_delete => true).bind(xchange).subscribe do |header, payload|
    puts "Got a payload: #{payload}"
  end

  EventMachine.add_periodic_timer(0.5) {
    xchange.publish("à bientôt!", :key => q.name)
  }


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."

    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(3, show_stopper)
end
