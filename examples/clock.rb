# encoding: utf-8

require 'bundler'
Bundler.setup
Bundler.require :default

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'

puts "=> Clock example"
puts
AMQP.start(:host => 'localhost') do |connection|

  puts "Connected!"

  show_stopper = lambda {
    puts "About to close AMQP connection…"
    connection.close { exit! } unless connection.closing?
  }

  # Send Connection.Close on Ctrl+C
  trap(:INT, &show_stopper)

  def log(*args)
    p args
  end

  # AMQP.logging = true

  channel = AMQP::Channel.new(connection)
  puts "Channel #{channel.id} is now open"
  producer   = channel.fanout('clock')
  EM.add_periodic_timer(1) {
    puts

    log :publishing, time = Time.now
    producer.publish(Marshal.dump(time))
  }

  channel2 = AMQP::Channel.new(connection)
  channel2.queue('every second').
    bind(channel2.fanout('clock')).
    subscribe(:confirm => proc { puts "Subscribed!" }) { |time|
      log 'every second', :received, Marshal.load(time)
  }

  puts "channel #{channel2.id} consumer tags: #{channel2.consumers.keys.join(', ')}"

  # channel3 = AMQP::Channel.new
  channel3 = AMQP::Channel.new(connection)
  channel3.queue('every 5 seconds').
  bind(channel3.fanout('clock')).
  subscribe { |time|
    time = Marshal.load(time)
    log 'every 5 seconds', :received, time if time.strftime('%S').to_i % 5 == 0
  }

  EM.add_timer(7, show_stopper)
end
