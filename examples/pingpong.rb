# encoding: utf-8

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'

AMQP.start(:host => 'localhost') do |connection|
  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    # now change this to just EM.stop and it
    # unbinds instantly
    connection.close {
      EM.stop { exit }
    }
  end
  Signal.trap "INT", &show_stopper


  def log(*args)
    p [ Time.now, *args ]
  end

  # AMQP.logging = true

  amq      = AMQP::Channel.new(connection)
  exchange = AMQP::Exchange.default(amq)
  q1       = amq.queue('one')
  q2       = amq.queue('two')

  EM.add_periodic_timer(1) {
    puts

    log :sending, 'ping'
    exchange.publish('ping')
  }

  100.times do
    q1.publish('ping')
  end

  q1.subscribe do |msg|
    log 'one', :received, msg, :sending, 'pong'
    exchange.publish('pong')
  end
  q2.subscribe { |msg| log('two', :received, msg) }
end
