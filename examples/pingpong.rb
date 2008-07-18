$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

EM.run{

  def log *args
    p [ Time.now, *args ]
  end
  
  # AMQP.logging = true

  amq = MQ.new
  amq.queue('one').subscribe{ |headers, msg|
    log 'one', :received, msg, :from => headers.reply_to

    if headers.reply_to
      msg[1] = 'o'

      log 'one', :sending, msg, :to => headers.reply_to
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

  amq = MQ.new
  amq.direct.publish('ding', :key => 'one')
  EM.add_periodic_timer(1){
    log :sending, 'ping', :to => 'one', :from => 'two'
    amq.direct.publish('ping', :key => 'one', :reply_to => 'two')
  }

}

__END__

[Thu Jul 17 21:23:55 -0700 2008, "one", :received, "ding", {:from=>nil}]

[Thu Jul 17 21:23:56 -0700 2008, :sending, "ping", {:from=>"two", :to=>"one"}]
[Thu Jul 17 21:23:56 -0700 2008, "one", :received, "ping", {:from=>"two"}]
[Thu Jul 17 21:23:56 -0700 2008, "one", :sending, "pong", {:to=>"two"}]
[Thu Jul 17 21:23:56 -0700 2008, "two", :received, "pong"]

[Thu Jul 17 21:23:57 -0700 2008, :sending, "ping", {:from=>"two", :to=>"one"}]
[Thu Jul 17 21:23:57 -0700 2008, "one", :received, "ping", {:from=>"two"}]
[Thu Jul 17 21:23:57 -0700 2008, "one", :sending, "pong", {:to=>"two"}]
[Thu Jul 17 21:23:57 -0700 2008, "two", :received, "pong"]