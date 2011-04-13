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
    channel.queue("Everything about development").bind(exchange, :routing_key => "technology.dev.#").subscribe do |payload|
      puts "A new dev post: '#{payload}'"
    end
    channel.queue("Everything about rubies").bind(exchange, :routing_key => "#.ruby").subscribe do |headers, payload|
      puts "A new post about rubies: '#{payload}', routing key = #{headers.routing_key}"
    end

    # Let's publish some test data.
    exchange.publish "Ruby post",     :routing_key => "technology.dev.ruby"
    exchange.publish "Erlang post",   :routing_key => "technology.dev.erlang"
    exchange.publish "Sinatra post",  :routing_key => "technology.web.ruby"
    exchange.publish "Jewelery post", :routing_key => "jewelery.ruby"



    show_stopper = Proc.new {
      connection.close do
        EM.stop
      end
    }

    Signal.trap "INT",  show_stopper
    Signal.trap "TERM", show_stopper

    EM.add_timer(1, show_stopper)
  end
end
