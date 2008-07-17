$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

EM.run{

  def log *args
    p [ Time.now, *args ]
  end
  
  # AMQP.logging = true

  amq = MQ.new
  amq.queue('one').subscribe{ |headers, msg|
    log 'one', :received, msg, :reply_to => headers.reply_to

    if headers.reply_to
      msg[1] = 'o'
      log 'one', :sending, msg, :to, headers.reply_to

      amq.direct.publish(msg, :key => headers.reply_to)
    else
      puts
    end
  }
  
  amq = MQ.new
  amq.queue('two').subscribe{ |msg|
    log 'two', :received, msg
    puts
  }

  EM.add_periodic_timer(1){
    log 'two', :sending, 'ping'
    amq.direct.publish('ping', :key => 'one', :reply_to => 'two')
  }
  amq.direct.publish('ding', :key => 'one')

}

__END__

[Thu Jul 17 14:49:58 -0700 2008, "one", :received, "ding", {:reply_to=>nil}]

[Thu Jul 17 14:49:59 -0700 2008, "two", :sending, "ping"]
[Thu Jul 17 14:49:59 -0700 2008, "one", :received, "ping", {:reply_to=>"two"}]
[Thu Jul 17 14:49:59 -0700 2008, "one", :sending, "pong", :to, "two"]
[Thu Jul 17 14:49:59 -0700 2008, "two", :received, "pong"]

[Thu Jul 17 14:50:00 -0700 2008, "two", :sending, "ping"]
[Thu Jul 17 14:50:00 -0700 2008, "one", :received, "ping", {:reply_to=>"two"}]
[Thu Jul 17 14:50:00 -0700 2008, "one", :sending, "pong", :to, "two"]
[Thu Jul 17 14:50:00 -0700 2008, "two", :received, "pong"]

[Thu Jul 17 14:50:01 -0700 2008, "two", :sending, "ping"]
[Thu Jul 17 14:50:01 -0700 2008, "one", :received, "ping", {:reply_to=>"two"}]
[Thu Jul 17 14:50:01 -0700 2008, "one", :sending, "pong", :to, "two"]
[Thu Jul 17 14:50:01 -0700 2008, "two", :received, "pong"]