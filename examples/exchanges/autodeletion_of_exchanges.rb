#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Exchange#initialize example that uses :auto_delete => true"
puts
AMQP.start(:host => 'localhost', :port => 5673) do |connection|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    AMQP::Exchange.new(channel, :direct, "amqpgem.examples.xchange2", :auto_delete => false) do |exchange|
      puts "#{exchange.name} is ready to go"
    end

    AMQP::Exchange.new(channel, :direct, "amqpgem.examples.xchange3", :auto_delete => true) do |exchange|
      puts "#{exchange.name} is ready to go"
    end
  end

  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close { EventMachine.stop }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(2, show_stopper)
end
