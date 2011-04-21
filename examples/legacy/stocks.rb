#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))
require 'amqp'

AMQP.start(:host => 'localhost') do |connection|
  def log(*args)
    p [ Time.now, *args ]
  end

  AMQP::Channel.new(connection) do |ch, open_ok|
    EM.add_periodic_timer(1) do
      puts

      {
        :appl => 170 + rand(1000) / 100.0,
        :msft => 22 + rand(500) / 100.0
      }.each do |stock, price|
        price = price.to_s
        stock = "usd.#{stock}"
        
        log :publishing, stock, price
        ch.topic('stocks').publish(price, :key => stock) if connection.open?
      end # each
    end # add_periodic_timer
  end # Channel.new


  AMQP::Channel.new do |ch, open_ok|
    ch.queue('apple stock').bind(ch.topic('stocks'), :key => 'usd.appl').subscribe { |price|
      log 'apple stock', price
    }
  end

  AMQP::Channel.new do |ch, open_ok|
    ch.queue('us stocks').bind(ch.topic('stocks'), :key => 'usd.*').subscribe { |info, price|
      log 'us stocks', info.routing_key, price
    }
  end



  show_stopper = Proc.new {
    connection.close do
      puts "Connection is now closed properly"
      EM.stop
    end
  }

  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper

  EM.add_timer(3, show_stopper)

end
