# encoding: utf-8

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'amqp'

if RUBY_VERSION == "1.8.7"
  module ArrayExtensions
    def sample
      self.choice
    end # sample
  end

  class Array
    include ArrayExtensions
  end
end



EM.run do
  connection = AMQP.connect
  ch         = AMQP::Channel.new(connection)

  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    # now change this to just EM.stop and it
    # unbinds instantly
    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", &show_stopper

  $stdout.puts "Bound! Running #{AMQP::VERSION} version of the gem."

  queue1    = ch.queue("queue1")
  queue2    = ch.queue("queue2")
  queue3    = ch.queue("queue3")

  queues    = [queue1, queue2, queue3]

  # Rely on default direct exchange binding, see section 2.1.2.4 Automatic Mode in AMQP 0.9.1 spec.
  exchange = ch.default_exchange

  queue1.subscribe do |payload|
    puts "Got #{payload} for #{queue1.name}"
  end

  queue2.subscribe do |payload|
    puts "New message to queue #{queue2.name}"
  end

  queue3.subscribe do |payload|
    puts "There is a message for #{queue3.name}"
  end

  EM.add_periodic_timer(1) do
    q = queues.sample

    $stdout.puts "Publishing to default exchange with routing key = #{q.name}..."
    exchange.publish "Some payload", :routing_key => q.name
  end
end
