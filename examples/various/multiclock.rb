#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'
require 'time'

AMQP.start(:host => 'localhost') do |connection|

  # Send Connection.Close on Ctrl+C
  trap(:INT) do
    unless connection.closing?
      connection.close { exit! }
    end
  end

  def log(*args)
    p args
  end

  #AMQP.logging = true

  clock = AMQP::Channel.new.headers('multiformat_clock')
  EM.add_periodic_timer(1) {
    puts

    time = Time.new
    ["iso8601", "rfc2822"].each do |format|
      formatted_time = time.send(format)
      log :publish, format, formatted_time
      clock.publish "#{formatted_time}", :headers => {"format" => format}
    end
  }

  ["iso8601", "rfc2822"].each do |format|
    amq = AMQP::Channel.new
    amq.queue(format.to_s).bind(amq.headers('multiformat_clock'), :arguments => {"format" => format}).subscribe { |time|
      log "received #{format}", time
    }
  end

  show_stopper = Proc.new {
    connection.close
  }

  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper

  EM.add_timer(3, show_stopper)

end
