#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  AMQP.connect(:host => '127.0.0.1', :port => 5672) do |connection|
    puts "Connected to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."


    connection.on_error do |conn, connection_close|
      puts <<-ERR
      Handling a connection-level exception.

      AMQP class id : #{connection_close.class_id},
      AMQP method id: #{connection_close.method_id},
      Status code   : #{connection_close.reply_code}
      Error message : #{connection_close.reply_text}
      ERR

      EventMachine.stop
    end

    # send_frame is NOT part of the public API, but it is public for entities like AMQ::Client::Channel
    # and we use it here to trigger a connection-level exception. MK.
    connection.send_frame(AMQ::Protocol::Connection::TuneOk.encode(1000, 1024 * 128 * 1024, 10))
  end
end
