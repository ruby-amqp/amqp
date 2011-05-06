#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../../lib", __FILE__))
require 'amqp'
require "amqp/extensions/rabbitmq"

AMQP.start do |connection|
  puts "Connected!"
  AMQP::Channel.new(connection) do |channel|
    puts "Channel #{channel.id} is now open"

    channel.confirm_select
    channel.on_error do
      puts "Oops, there is a channel-levle exceptions!"
    end


    channel.on_ack do |basic_ack|
      puts "Received basic_ack: multiple = #{basic_ack.multiple}, delivery_tag = #{basic_ack.delivery_tag}"
    end

    x = channel.fanout("amq.fanout")
    channel.queue("", :auto_delete => true) do |q|
      puts "Declared a new server-named qeueue: #{q.name}"

      q.bind(x, :no_ack => true).subscribe(:ack => true) do |header, payload|
        puts "Received #{payload}"
      end
    end

    EventMachine.add_timer(0.5) do
      10.times do |i|
        puts "Publishing message ##{i}"
        x.publish("Message ##{i}")
      end
    end
  end

  show_stopper = Proc.new {
    AMQP.stop do
      EM.stop
    end
  }


  EM.add_timer(3, show_stopper)
  Signal.trap('INT',  show_stopper)
  Signal.trap('TERM', show_stopper)
end
