# encoding: utf-8

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

  # AMQP.logging = true

  amq = AMQP::Channel.new(connection)
  EM.add_periodic_timer(1) {
    puts

    log :sending, 'ping'
    amq.queue('one').publish('ping')
  }

  amq = AMQP::Channel.new(connection)
  amq.queue('one').subscribe { |msg|
    log 'one', :received, msg, :sending, 'pong'
    amq.queue('two').publish('pong')
  }

  amq = AMQP::Channel.new(connection)
  amq.queue('two').subscribe { |msg|
    log 'two', :received, msg
  }

end
