$:.unshift File.dirname(__FILE__) + '/../../lib'
require 'mq'
require 'pp'

EM.run do
  
  # open a channel on the AMQP connection
  channel = MQ.new

  # declare a queue on the channel
  queue = MQ::Queue.new(channel, 'queue name')

  # use the default fanout exchange
  exchange = MQ::Exchange.new(channel, :fanout, 'all queues')

  # bind the queue to the exchange
  queue.bind(exchange)

  # publish a message to the exchange
  exchange.publish('hello world')

  # subscribe to messages from the queue 
  queue.subscribe do |headers, msg|
    pp [:got, headers, msg]
    EM.stop_event_loop
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
