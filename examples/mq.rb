$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

EM.run{

  def log *args
    p [ Time.now, *args ]
  end
  
  # AMQP.logging = true

  amq = MQ.new
  amq.queue('one').subscribe{ |headers, msg|
    log 'one got', msg
    if headers.reply_to
      msg[1] = 'o'
      log 'one sending', msg
      amq.direct.publish(msg, :key => headers.reply_to)
    end
  }
  
  amq = MQ.new
  amq.queue('two').subscribe{ |msg|
    log 'two got', msg
    puts
  }

  amq.direct.publish('ding', :key => 'one')

  EM.add_periodic_timer(1){
    log 'two sending', 'ping'
    amq.direct.publish('ping', :key => 'one', :reply_to => 'two')
  }

}

__END__

$ ruby examples/mq.rb 
[Thu Jul 17 14:06:07 -0700 2008, "one got", "ding"]

[Thu Jul 17 14:06:08 -0700 2008, "two sending", "ping"]
[Thu Jul 17 14:06:08 -0700 2008, "one got", "ping"]
[Thu Jul 17 14:06:08 -0700 2008, "one sending", "pong"]
[Thu Jul 17 14:06:08 -0700 2008, "two got", "pong"]

[Thu Jul 17 14:06:09 -0700 2008, "two sending", "ping"]
[Thu Jul 17 14:06:09 -0700 2008, "one got", "ping"]
[Thu Jul 17 14:06:09 -0700 2008, "one sending", "pong"]
[Thu Jul 17 14:06:09 -0700 2008, "two got", "pong"]
