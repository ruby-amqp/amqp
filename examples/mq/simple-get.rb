$:.unshift File.dirname(__FILE__) + '/../../lib'
require 'mq'
require 'pp'

Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

EM.run do
  MQ.queue('awesome').publish('Totally rad 1')
  MQ.queue('awesome').publish('Totally rad 2')
  EM.add_timer(5) { MQ.queue('awesome').publish('Totally rad 3') }
  
  #This is the block that does the processing and calls pop again when it's done
  #If the message to the proc is :empty, it tells the worker to issues another pop
  #in 5 seconds
  process = Proc.new do |h,m| 
    if m == :empty
      opts = {:delay => 5}
    else
      opts = {}
      puts m
    end
    MQ.queue('awesome').pop(opts, &process)
  end
  MQ.queue('awesome').pop &process
end

__END__

Totally rad 1
Totally rad 2
...5 second delay...
Totally rad 3
