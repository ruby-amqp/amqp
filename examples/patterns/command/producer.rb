# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"
require "yaml"

t = Thread.new { EventMachine.run }
sleep(0.5)

connection = AMQP.connect
channel    = AMQP::Channel.new(connection)

# publish new commands every few seconds
EventMachine.add_periodic_timer(10.0) do
  puts "Publishing a command (gems.install)"
  payload = { :gem => "rack", :version => "~> 1.3.0" }.to_yaml

  channel.default_exchange.publish(payload,
                                   :type        => "gems.install",
                                   :routing_key => "amqpgem.examples.patterns.command")
end

puts "[boot] Ready. Will be publishing commands every 10 seconds."
Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join
