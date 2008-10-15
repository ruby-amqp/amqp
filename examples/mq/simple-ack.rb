$:.unshift File.dirname(__FILE__) + '/../../lib'
require 'mq'
require 'pp'

# For ack to work appropriatly you must shutdown AMQP gracefully,
# otherwise all items in your queue will be returned
Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

EM.run do
  MQ.queue('awesome').publish('Totally rad 1')
  MQ.queue('awesome').publish('Totally rad 2')
  MQ.queue('awesome').publish('Totally rad 3')

  i = 0
  # Stopping after the second item was acked will keep the 3rd item in the queue
  MQ.queue('awesome').subscribe(:no_ack => false) do |h,m|
    if i == 2
      AMQP.stop{ EM.stop }
    else
      puts m
      i += 1
    end
  end
end

__END__

Totally rad 1
Totally rad 2
Shutting down...

When restarted:

Totally rad 3
Totally rad 1
Shutting down...
