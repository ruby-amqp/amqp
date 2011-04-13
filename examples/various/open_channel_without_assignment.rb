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


puts "=> Queue#status example"
puts
AMQP.start(:host => 'localhost') do |connection|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"
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
