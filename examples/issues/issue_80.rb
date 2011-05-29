#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "Running amqp gem #{AMQP::VERSION}"


AMQP.start("amqp://guest:guest@localhost:5672") do |connection, open_ok|
  channel  = AMQP::Channel.new(connection)
  channel.on_error { |ch, channel_close| puts "Error #{channel_close.inspect}" }
  queue    = channel.queue("reset_test", :auto_delete => false, :durable=>true)
  exchange = channel.direct("foo")
  queue.bind(exchange) { puts 'Got bind ok'}

  EM.add_timer(2) do
    channel.reset
    queue    = channel.queue("reset_test", :auto_delete => false, :durable=>true)
    exchange = channel.direct("foo")
    queue.unbind(exchange) { puts 'Got unbind ok'}
  end

  show_stopper = Proc.new do
    $stdout.puts "Stopping..."

    queue.delete
    exchange.delete
    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(4, show_stopper)
end
