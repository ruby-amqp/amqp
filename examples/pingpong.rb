$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

EM.run{

  def log *args
    p [ Time.now, *args ]
  end
  
  # AMQP.logging = true

  amq = MQ.new
  EM.add_periodic_timer(1){
    puts

    log :sending, 'ping'
    amq.queue('one').publish('ping')
  }

  amq = MQ.new
  amq.queue('one').subscribe{ |headers, msg|
    log 'one', :received, msg, :sending, 'pong'
    amq.queue('two').publish('pong')
  }
  
  amq = MQ.new
  amq.queue('two').subscribe{ |msg|
    log 'two', :received, msg
  }

}

__END__

[Sun Jul 20 03:52:24 -0700 2008, :sending, "ping"]
[Sun Jul 20 03:52:24 -0700 2008, "one", :received, "ping", :sending, "pong"]
[Sun Jul 20 03:52:24 -0700 2008, "two", :received, "pong"]

[Sun Jul 20 03:52:25 -0700 2008, :sending, "ping"]
[Sun Jul 20 03:52:25 -0700 2008, "one", :received, "ping", :sending, "pong"]
[Sun Jul 20 03:52:25 -0700 2008, "two", :received, "pong"]

[Sun Jul 20 03:52:26 -0700 2008, :sending, "ping"]
[Sun Jul 20 03:52:26 -0700 2008, "one", :received, "ping", :sending, "pong"]
[Sun Jul 20 03:52:26 -0700 2008, "two", :received, "pong"]
