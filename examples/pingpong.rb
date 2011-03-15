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
  q1  = amq.queue('one')
  q2  = amq.queue('two')

  EM.add_periodic_timer(1) {
    puts

    log :sending, 'ping'
    q1.publish('ping')
  }

  q1.subscribe { |msg|
    log 'one', :received, msg, :sending, 'pong'
    q2.publish('pong')
  }

  #q2.subscribe { |msg|
  #  log 'two', :received, msg
  #}

end
