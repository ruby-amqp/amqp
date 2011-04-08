#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'

AMQP.start(:host => 'localhost') do |connection|

  # Send Connection.Close on Ctrl+C
  trap(:INT) do
    unless connection.closing?
      connection.close { exit! }
    end
  end

  def log(*args)
    p [ Time.now, *args ]
  end

  def publish_stock_prices
    mq = AMQP::Channel.new
    EM.add_periodic_timer(1) {
      puts

      { :appl => 170 + rand(1000) / 100.0,
        :msft => 22 + rand(500) / 100.0
      }.each do |stock, price|
        price = price.to_s
        stock = "usd.#{stock}"

        log :publishing, stock, price
        mq.topic('stocks').publish(price, :key => stock)
      end
    }
  end

  def watch_appl_stock
    mq = AMQP::Channel.new
    mq.queue('apple stock').bind(mq.topic('stocks'), :key => 'usd.appl').subscribe { |price|
      log 'apple stock', price
    }
  end

  def watch_us_stocks
    mq = AMQP::Channel.new
    mq.queue('us stocks').bind(mq.topic('stocks'), :key => 'usd.*').subscribe { |info, price|
      log 'us stock', info.routing_key, price
    }
  end

  publish_stock_prices
  watch_appl_stock
  watch_us_stocks

  show_stopper = Proc.new {
    connection.close
  }

  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper

  EM.add_timer(3, show_stopper)

end
