# encoding: utf-8

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'

# For ack to work appropriately you must shutdown AMQP gracefully,
# otherwise all items in your queue will be returned
Signal.trap('INT')  { AMQP.stop { puts "About to stop EM reactor"; EM.stop } }
Signal.trap('TERM') { AMQP.stop { puts "About to stop EM reactor"; EM.stop } }

AMQP.start(:host => 'localhost') do |connection|
  puts "Connected!"
  channel = AMQP::Channel.new(connection)

  channel.queue('awesome').publish('Totally rad 1')
  channel.queue('awesome').publish('Totally rad 2')
  channel.queue('awesome').publish('Totally rad 3')

  i = 0

  # Stopping after the second item was acked will keep the 3rd item in the queue
  channel.queue('awesome').subscribe(:ack => true) do |h, m|
    if (i += 1) == 3
      puts 'Shutting down...'
      AMQP.stop { EM.stop }
    end

    if AMQP.closing?
      puts "#{m} (ignored, redelivered later)"
    else
      puts m
      h.ack
    end
  end
end
