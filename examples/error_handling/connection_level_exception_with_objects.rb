#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


class ConnectionManager

  #
  # API
  #

  def connect(*args, &block)
    @connection = AMQP.connect(*args, &block)

    # combines Object#method and Method#to_proc to use object
    # method as a callback
    @connection.on_error(&method(:on_error))
  end # connect(*args, &block)


  def on_error(connection, connection_close)
    puts "Handling a connection-level exception."
    puts
    puts "AMQP class id : #{connection_close.class_id}"
    puts "AMQP method id: #{connection_close.method_id}"
    puts "Status code   : #{connection_close.reply_code}"
    puts "Error message : #{connection_close.reply_text}"
  end # on_error(connection, connection_close)
end

EventMachine.run do
  manager = ConnectionManager.new
  manager.connect(:host => '127.0.0.1', :port => 5672) do |connection|
    puts "Connected to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

    # send_frame is NOT part of the public API, but it is public for entities like AMQ::Client::Channel
    # and we use it here to trigger a connection-level exception. MK.
    connection.send_frame(AMQ::Protocol::Connection::TuneOk.encode(1000, 1024 * 128 * 1024, 10))
  end

  # shut down after 2 seconds
  EventMachine.add_timer(2) { EventMachine.stop }
end
