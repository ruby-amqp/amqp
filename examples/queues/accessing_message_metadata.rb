#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."

  channel  = AMQP::Channel.new(connection)
  queue    = channel.queue("amqpgem.examples.hello_world", :auto_delete => true)
  exchange = channel.direct("amq.direct")

  queue.bind(exchange)

  channel.on_error do |ch, channel_close|
    puts channel_close.reply_text
    connection.close { EventMachine.stop }
  end

  queue.subscribe do |metadata, payload|
    puts "metadata.routing_key : #{metadata.routing_key}"
    puts "metadata.content_type: #{metadata.content_type}"
    puts "metadata.priority    : #{metadata.priority}"
    puts "metadata.headers     : #{metadata.headers.inspect}"
    puts "metadata.timestamp   : #{metadata.timestamp.inspect}"
    puts "metadata.type        : #{metadata.type}"
    puts "metadata.delivery_tag: #{metadata.delivery_tag}"
    puts "metadata.redelivered : #{metadata.redelivered?}"

    puts "metadata.app_id      : #{metadata.app_id}"
    puts "metadata.exchange    : #{metadata.exchange}"
    puts
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close {
      EventMachine.stop { exit }
    }
  end

  exchange.publish("Hello, world!",
                   :app_id      => "amqpgem.example",
                   :priority    => 8,
                   :type        => "kinda.checkin",
                   # headers table keys can be anything
                   :headers     => {
                     :coordinates => {
                       :latitude  => 59.35,
                       :longitude => 18.066667
                     },
                     :participants => 11,
                     :venue        => "Stockholm"
                   },
                   :timestamp   => Time.now.to_i)
end
