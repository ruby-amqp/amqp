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
    log 'one', :received, msg
    log 'one', :sending, 'pong'
    amq.queue('two').publish('pong')
  }
  
  amq = MQ.new
  amq.queue('two').subscribe{ |msg|
    log 'two', :received, msg
  }

}

__END__

[Fri Jul 18 19:34:39 -0700 2008, :sending, "ping"]
[Fri Jul 18 19:34:39 -0700 2008, "one", :received, "ping"]
[Fri Jul 18 19:34:39 -0700 2008, "one", :sending, "pong"]
[Fri Jul 18 19:34:39 -0700 2008, "two", :received, "pong"]

[Fri Jul 18 19:34:40 -0700 2008, :sending, "ping"]
[Fri Jul 18 19:34:40 -0700 2008, "one", :received, "ping"]
[Fri Jul 18 19:34:40 -0700 2008, "one", :sending, "pong"]
[Fri Jul 18 19:34:40 -0700 2008, "two", :received, "pong"]

[Fri Jul 18 19:34:41 -0700 2008, :sending, "ping"]
[Fri Jul 18 19:34:41 -0700 2008, "one", :received, "ping"]
[Fri Jul 18 19:34:41 -0700 2008, "one", :sending, "pong"]
[Fri Jul 18 19:34:41 -0700 2008, "two", :received, "pong"]