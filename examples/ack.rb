# encoding: utf-8

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'


AMQP.start do |connection|
  puts "Connected!"
  channel = AMQP::Channel.new(connection)
  e       = channel.fanout("amqp-gem.examples.ack")
  q       = channel.queue('amqp-gem.examples.q1').bind(e)

  i = 0

  # Stopping after the second item was acked will keep the 3rd item in the queue
  q.subscribe(:ack => true) do |h, m|
    puts "Got a message"

    if AMQP.closing?
      puts "#{m} (ignored, redelivered later)"
    else
      puts m
      h.ack
    end
  end # channel.queue


  10.times do |i|
    puts "Publishing message ##{i}"
    e.publish("Totally rad #{i}")
  end


  show_stopper = Proc.new {
    q.unbind(e) do
      puts "Unbound #{q.name} from #{e.name}"

      AMQP.stop do
        puts "About to stop EM reactor"
        EM.stop
      end
    end
  }

  EM.add_timer(3, show_stopper)

  # For ack to work appropriately you must shutdown AMQP gracefully,
  # otherwise all items in your queue will be returned
  Signal.trap('INT',  show_stopper)
  Signal.trap('TERM', show_stopper)
end # AMQP.start
