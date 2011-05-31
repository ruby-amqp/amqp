#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Subscribing for messages using explicit acknowledgements model"
puts

# this example uses Kernel#sleep and thus we must run EventMachine reactor in
# a separate thread, or nothing will be sent/received while we sleep() on the current thread.
t = Thread.new { EventMachine.run }
sleep(0.5)

# open two connections to imitate two apps
connection1 = AMQP.connect
connection2 = AMQP.connect
connection3 = AMQP.connect

channel_exception_handler = Proc.new { |ch, channel_close| EventMachine.stop; raise "channel error: #{channel_close.reply_text}" }

# open two channels
channel1    = AMQP::Channel.new(connection1)
channel1.on_error(&channel_exception_handler)
# first app will be given up to 3 messages at a time. If it doesn't
# ack any messages after it was delivered 3, messages will be routed to
# the app #2.
channel1.prefetch(3)

channel2    = AMQP::Channel.new(connection2)
channel2.on_error(&channel_exception_handler)
# app #2 processes messages one-by-one and has to send and ack every time
channel2.prefetch(1)

# app 3 will just publish messages
channel3    = AMQP::Channel.new(connection3)
channel3.on_error(&channel_exception_handler)

exchange = channel3.direct("amq.direct")

queue1    = channel1.queue("amqpgem.examples.acknowledgements.explicit", :auto_delete => false)
# purge the queue so that we don't get any redeliveries from previous runs
queue1.purge
queue1.bind(exchange).subscribe(:ack => true) do |metadata, payload|
  # do some work
  sleep(0.2)

  # acknowledge some messages, they will be removed from the queue
  if rand > 0.5
    # FYI: there is a shortcut, metadata.ack
    channel1.acknowledge(metadata.delivery_tag, false)
    puts "[consumer1] Got message ##{metadata.headers['i']}, ack-ed"
  else
    # some messages are not ack-ed and will remain in the queue for redelivery
    # when app #1 connection is closed (either properly or due to a crash)
    puts "[consumer1] Got message ##{metadata.headers['i']}, SKIPPPED"
  end
end

queue2    = channel2.queue!("amqpgem.examples.acknowledgements.explicit", :auto_delete => false)
queue2.subscribe(:ack => true) do |metadata, payload|
  metadata.ack
  # app 2 always acks messages
  puts "[consumer2] Received #{payload}, redelivered = #{metadata.redelivered}, ack-ed"
end

# after some time one of the consumers quits/crashes
EventMachine.add_timer(4.0) {
  connection1.close
  puts "----- Connection 1 is now closed (we pretend that it has crashed) -----"
}

EventMachine.add_timer(10.0) do
  # purge the queue so that we don't get any redeliveries on the next run
  queue2.purge {
    connection2.close {
      connection3.close { EventMachine.stop }
    }
  }
end


i = 0
EventMachine.add_periodic_timer(0.8) {
  3.times do
    exchange.publish("Message ##{i}", :headers => { :i => i })
    i += 1
  end
}


t.join
