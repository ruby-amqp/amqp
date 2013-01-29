#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connecting to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

  channel   = AMQP::Channel.new(connection)
  queue     = channel.queue("amqpgem.examples.hello_world", :auto_delete => true)
  exchange1 = channel.fanout("my.fanout1", :auto_delete => true)
  exchange2 = channel.fanout("my.fanout2", :auto_delete => true, :arguments => { "alternate-exchange" => "my.fanout1" })

  queue.bind(exchange1).subscribe do |payload|
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close { EventMachine.stop }
  end

  exchange1.publish "This message will be routed because of the binding",   :mandatory => true
  exchange2.publish "This message will be re-routed to alternate-exchange", :mandatory => true
end
