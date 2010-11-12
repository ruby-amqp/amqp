# encoding: utf-8

$:.unshift File.expand_path("../../../lib", __FILE__)
require "mq"

AMQP.start(:host => "localhost") do
  @counter = 0
  amq = MQ.new

  3.times do
    amq.queue("") do |method|
      puts "Queue #{method.queue} declared."
      puts "All queues: #{amq.queues.map(&:name).inspect}", ""

      @counter += 1
    end
  end

  EM.add_periodic_timer(0.1) do
    EM.stop if @counter == 3
  end
end
