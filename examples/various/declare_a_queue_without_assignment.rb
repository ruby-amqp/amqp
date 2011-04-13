#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue#initialize example that uses a block"
puts
AMQP.start(:host => 'localhost') do |connection|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    AMQP::Queue.new(channel, "", :auto_delete => true) do |queue|
      puts "#{queue.name} is ready to go"
    end

    AMQP::Queue.new(channel, "", :auto_delete => true) do |queue, declare_ok|
      puts "#{queue.name} is ready to go. AMQP method: #{declare_ok.inspect}"
    end

    channel.queue("", :auto_delete => true) do |queue, declare_ok|
      puts "#{queue.name} is ready to go. AMQP method: #{declare_ok.inspect}"
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."

    # queue.purge :nowait => true

    # now change this to just EM.stop and it
    # unbinds instantly
    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(2, show_stopper)
end
