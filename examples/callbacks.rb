# encoding: utf-8

$:.unshift File.expand_path("../../lib", __FILE__)
require "amqp"

AMQP.start(:host => "localhost") do |connection|

  # Send Connection.Close on Ctrl+C
  trap(:INT) do
    unless connection.closing?
      connection.close { exit! }
    end
  end

  @counter = 0
  amq = AMQP::Channel.new

  amq.prefetch(64, false) do
    puts "basic.qos callback has fired"
  end

  10.times do
    amq.queue("") do |queue|
      puts "Queue #{queue.name} is now declared."
      puts "All queues: #{amq.queues.map { |q| q.name }.join(', ')}"

      @counter += 1
    end
  end

  EM.add_timer(0.3) do
    connection.disconnect do
      puts "AMQP connection is now closed."
      EM.stop
    end
  end
end
