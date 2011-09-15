#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require "amqp"

puts "Running amqp gem #{AMQP::VERSION}"

EM.run do
  AMQP.start do
    puts "AMQP connection connected: #{AMQP.connection.connected?}"
    EM.add_timer(5) do
      puts "Stopping AMQP"
      AMQP.stop do
        EM.stop
      end
    end
  end
end