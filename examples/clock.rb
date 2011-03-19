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
  exchange = channel2.fanout('clock')

  q1       = channel2.queue('every second')
  q1.bind(exchange).subscribe(:confirm => proc { puts "Subscribed!" }) { |time|
      log 'every second', :received, Marshal.load(time)
  }

  puts "channel #{channel2.id} consumer tags: #{channel2.consumers.keys.join(', ')}"

  # channel3 = AMQP::Channel.new
  channel3 = AMQP::Channel.new(connection)
  q2 = channel3.queue('every 5 seconds')
  q2.bind(exchange).subscribe { |time|
    time = Marshal.load(time)
    log 'every 5 seconds', :received, time if time.strftime('%S').to_i % 5 == 0
  }

  show_stopper = Proc.new {
    q1.unbind(exchange)
    q2.unbind(exchange) do
      puts "Unbound #{q2.name}. About to close AMQP connection…"
      connection.close { exit! } unless connection.closing?
    end
  }

  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper

  EM.add_timer(7, show_stopper)
end
