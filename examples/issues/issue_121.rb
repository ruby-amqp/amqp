#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))



require 'amqp'
require 'amqp/extensions/rabbitmq'
AMQP.start(:user => 'guest',:pass => 'guest',:vhost => '/') do |connection|
  channel = AMQP::Channel.new(connection)
  channel.queue("shuki_q",{:nowait => true,:passive=>false, :auto_delete=>false, :arguments=>{"x-expires"=>5600000}}) do |queue|
    queue.bind('raw.shuki',:routing_key => 'ShukiesTukies')
    puts "before subscribe"
    queue.subscribe(:ack => true) do |header, payload|
      puts "inside subscribe"
      p header.class
    end
  end
end
