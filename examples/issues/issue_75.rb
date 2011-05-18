#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

AMQP.start(:host => "localhost") do |connection|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.fanout("logs", :auto_delete => false)

  EM.add_timer(500) do
    connection.close do
      EM.stop { exit }
    end
  end
end