#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require "amqp"

puts "Running amqp gem #{AMQP::VERSION}"

AMQP.start(:host => '127.0.0.1') do |connection|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.direct("")
  queue    = channel.queue("indexer_queue", { :durable => true })

  EM.add_periodic_timer(1) {
    queue.status do |num_messages, num_consumers|
      puts "msgs:#{num_messages}"
    end
  }
end