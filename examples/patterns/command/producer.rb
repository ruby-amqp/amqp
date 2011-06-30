# encoding: utf - 8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"

t = Thread.new { EventMachine.run }
sleep(0.5)

connection = AMQP.connect
channel    = AMQP::Channel.new(connection)


command = "df -h"

# publish new commands every 3 seconds
EventMachine.add_periodic_timer(3.0) do
  puts "Publishing a command (#{command})"
  channel.default_exchange.publish(command, :routing_key => "amqpgem.examples.tasks")
end

Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join
