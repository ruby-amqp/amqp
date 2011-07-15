#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require 'amqp'

puts "Running amqp gem #{AMQP::VERSION}"


AMQP.start("amqp://guest:guest@localhost:5672") do |connection, open_ok|
  ch = AMQP::Channel.new(connection)
  ch.direct("amqpgem.issues.93.1")
  ch.direct("amqpgem.issues.93.2", :auto_delete => false)
  ch.direct("amqpgem.issues.93.3") do |ex, declare_ok|
  end
  ch.direct("amqpgem.issues.93.4", :auto_delete => false) do |ex, declare_ok|
  end
  ch.direct("amqpgem.issues.93.5", :auto_delete => true)
  ch.direct("amqpgem.issues.93.6", :auto_delete => true) do |ex, declare_ok|
  end

  puts "Done"
end