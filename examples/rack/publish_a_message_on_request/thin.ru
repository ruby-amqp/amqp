use Rack::CommonLogger

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../../lib", __FILE__))

require 'amqp'
require 'amqp/utilities/event_loop_helper'

puts "EventMachine.reactor_running? => #{EventMachine.reactor_running?.inspect}"

AMQP::Utilities::EventLoopHelper.run do
  AMQP.start

  exchange          = AMQP.channel.fanout("amq.fanout")

  q = AMQP.channel.queue("", :auto_delete => true, :exclusive => true)
  q.bind(exchange)
  AMQP::channel.default_exchange.publish("Started!", :routing_key => q.name)
end

app = proc do |env|
  AMQP.channel.fanout("amq.fanout").publish("Served a request at (#{Time.now.to_i})")

  [
    200,          # Status code
    {             # Response headers
      'Content-Type' => 'text/html',
      'Content-Length' => '2',
    },
    ['hi']        # Response body
  ]
end

run app