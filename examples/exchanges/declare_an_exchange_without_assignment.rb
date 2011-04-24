#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Exchange#initialize example that uses a block"
puts
AMQP.start(:host => 'localhost') do |connection|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    AMQP::Exchange.new(channel, :direct, "amqpgem.examples.xchange1", :auto_delete => true) do |exchange|
      puts "#{exchange.name} is ready to go"
    end

    AMQP::Exchange.new(channel, :direct, "amqpgem.examples.xchange1", :auto_delete => true) do |exchange, declare_ok|
      puts "#{exchange.name} is ready to go. AMQP method: #{declare_ok.inspect}"
    end

    channel.direct("amqpgem.examples.xchange2", :auto_delete => true) do |exchange, declare_ok|
      puts "#{exchange.name} is ready to go. AMQP method: #{declare_ok.inspect}"
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
