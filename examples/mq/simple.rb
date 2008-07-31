$:.unshift File.dirname(__FILE__) + '/../../lib'
require 'mq'
require 'pp'

EM.run do
  
  # open a channel on the AMQP connection
  channel = MQ.new

  # declare a queue on the channel
  queue = MQ::Queue.new(channel, 'queue name')

  # create a fanout exchange
  exchange = MQ::Exchange.new(channel, :fanout, 'all queues')

  # bind the queue to the exchange
  queue.bind(exchange)

  # publish a message to the exchange
  exchange.publish('hello world')

  # subscribe to messages in the queue
  queue.subscribe do |headers, msg|
    pp [:got, headers, msg]
    AMQP.stop
  end
  
end

__END__

[:got,
 #<AMQP::Protocol::Header:0x118a438
  @klass=AMQP::Protocol::Basic,
  @properties=
   {:priority=>0,
    :delivery_mode=>1,
    :content_type=>"application/octet-stream"},
  @size=11,
  @weight=0>,
 "hello world"]
