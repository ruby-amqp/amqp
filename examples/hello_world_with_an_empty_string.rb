#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1', :port => 5672)
  puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."


  connection.on_error do |conn, connection_close|
    puts "Handling a connection-level exception: #{connection_close.reply_text}"
  end

  channel  = AMQP::Channel.new(connection)
  queue    = channel.queue("amqpgem.examples.hello_world", :auto_delete => false)
  exchange = channel.direct("")

  queue.subscribe do |payload|
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close {
      EM.stop { exit }
    }
  end

  exchange.publish "1", :routing_key => queue.name, :app_id => "Hello world"
end
