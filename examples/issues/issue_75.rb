#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "Running amqp gem #{AMQP::VERSION}"

AMQP.start(:host => "localhost") do |connection|
  channel  = AMQP::Channel.new(connection)
  channel.fanout("logs.nad", :auto_delete => false)
  channel.fanout("logs.ad",  :auto_delete => true)

  EM.add_timer(1) do
    connection.close do
      EM.stop { exit }
    end
  end
end