#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require "amqp"

EventMachine.run do
  AMQP.connect do |connection|
    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic("pub/sub")

    # Subscribers.
    dev  = channel.queue("Everything about Development").bind(exchange, key: "it.dev.#")
    ruby = channel.queue("Everything about Ruby").bind(exchange, key: "it.#.ruby")

    # Let's publish some test data.
    exchange.publish "Ruby post", :routing_key => "it.dev.ruby"
    exchange.publish "Erlang post", :routing_key => "it.dev.erlang"
    exchange.publish "Sinatra post", :routing_key => "it.webs.ruby"
    exchange.publish "Jewellery post", :routing_key => "jewellery.ruby"

    # Subscribe to it.dev.#
    dev.subscribe do |payload|
      puts "A new dev post: '#{payload}'"
    end

    # Subscribe to it.#.ruby
    ruby.subscribe do |payload|
      puts "A new post about Ruby: '#{payload}'"
    end
  end
end

# Expected result:
# [STDOUT] A new post about Ruby: 'Ruby post'
# [STDOUT] A new dev post: 'Ruby post'
# [STDOUT] A new dev post: 'Erlang post'
# [STDOUT] A new post about Ruby: 'Sinatra post'
