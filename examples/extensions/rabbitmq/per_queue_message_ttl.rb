#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../../lib", __FILE__))
require 'amqp'
require "amqp/extensions/rabbitmq"

AMQP.start do |connection|
  puts "Connected!"
  AMQP::Channel.new(connection) do |channel, open_ok|
    puts "Channel #{channel.id} is now open"

    channel.on_error do |ch, channel_close|
      puts "Oops! a channel-level exception: #{channel_close.reply_text}"
    end

    x = channel.fanout("amq.fanout")
    channel.queue("", :auto_delete => true, :arguments => { "x-message-ttl" => 1000 }) do |q|
      puts "Declared a new server-named qeueue: #{q.name}"
      q.bind(x)


      EventMachine.add_timer(0.3) do
        10.times do |i|
          puts "Publishing message ##{i}"
          x.publish("Message ##{i}")
        end
      end

      EventMachine.add_timer(0.7) do
        q.pop do |headers, payload|
          raise "x-message-ttl didn't seem to work (timeout is up)" if payload.nil?
        end
      end

      EventMachine.add_timer(1.5) do
        q.pop do |headers, payload|
          raise "x-message-ttl didn't seem to work (timeout isn't up)" if payload
        end
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
