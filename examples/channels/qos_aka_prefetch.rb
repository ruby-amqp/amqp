#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Channel#prefetch"
puts
AMQP.start(:host => 'localhost') do |connection|
  ch = AMQP::Channel.new
  ch.on_error do |ch, channel_close|
    raise "Oops! a channel-level exception: #{channel_close.inspect}"
  end
  ch.prefetch(1, false) do |_|
    puts "qos callback has fired"
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."

    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", &show_stopper
  EM.add_timer(1, show_stopper)
end
