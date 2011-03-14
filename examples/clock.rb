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

  # Send Connection.Close on Ctrl+C
  trap(:INT) do
    unless connection.closing?
      connection.close { exit! }
    end
  end

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
    # producer.publish(Marshal.dump(time))
  }

  # channel2 = AMQP::Channel.new
  # channel2.queue('every second').bind(amq.fanout('clock')).subscribe { |time|
  #   log 'every second', :received, Marshal.load(time)
  # }

  # channel3 = AMQP::Channel.new
  # channel3.queue('every 5 seconds').bind(amq.fanout('clock')).subscribe { |time|
  #   time = Marshal.load(time)
  #   log 'every 5 seconds', :received, time if time.strftime('%S').to_i % 5 == 0
  # }

end
