# encoding: utf-8

$:.unshift File.dirname(__FILE__) + '/../lib'
require 'rubygems'
require 'amqp'

# AMQP.start do |amqp|
#   amqp.channel!(1)
#
#   q = amqp.queue.declare(:queue => 'test',
#                          :exclusive => false,
#                          :auto_delete => true)
#
#   q.bind(:exchange => '',
#          :routing_key => 'test_route')
#
#   amqp.basic.consume(:queue => q,
#                      :no_local => false,
#                      :no_ack => true) { |header, body|
#     p ['got', header, body]
#   }
# end

AMQP.start do |amqp|
  amqp.exchange('my_exchange', :topic) do |e|
    e.publish(routing_key, data, :header => 'blah')
  end

  amqp.queue('my_queue').subscribe do |header, body|
    p ['got', header, body]
  end
end

def AMQP::Channel.method_missing meth, *args, &blk
  (Thread.current[:mq] ||= AMQP::Channel.new).__send__(meth, *args, &blk)
end

mq = AMQP::Channel.new
mq.direct.publish('alkjsdf', :key => 'name')
mq.topic # 'amq.topic'
mq.topic('test').publish('some data', :key => 'stock.usd.*')

# amq.queue('user1').bind(amq.topic('conversation.1'))

mq.queue('abc').get {}
mq.queue('abc').peek {}
mq.queue('abc').subscribe { |body|

}

mq.queue('abc').bind(:exchange => mq.topic, :routing_key => 'abc', :nowait => true, :arguments => {})

