#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Channel#prefetch"
puts
AMQP.start(:host => 'localhost') do |connection|
  ch = AMQP::Channel.new(connection, AMQP::Channel.next_channel_id, :prefetch => 1)
  ch.on_error do |ex|
    raise "Oops! there has been a channel-level exception"
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."

    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(1, show_stopper)
end
