#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'amqp'

if RUBY_VERSION == "1.8.7"
  class Array
    alias sample choice
  end
end


puts "=> basic.get example"
puts
AMQP.start(:host => 'localhost') do |connection|
  channel    = AMQP::Channel.new(connection)
  exchange   = AMQP::Exchange.default
  queue_name = "amqp_gem.basic_get_example"
  queue      = channel.queue(queue_name, :auto_delete => true)

  n = 100
  n.times do |i|
    exchange.publish "Message #{i} from basic.get example", :key => queue_name
  end

  sleep 0.2
  (2 * n).times do
    queue.pop do |headers, payload|
      puts "Got '#{payload}' for '#{queue.name}'. Headers are #{headers.to_hash.inspect}"
    end
  end



  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    # now change this to just EM.stop and it
    # unbinds instantly
    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(3, show_stopper)
end
