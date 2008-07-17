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

    log :publishing, 'time', time = Time.now
    amq.fanout('clock').publish(Marshal.dump(time))
  }

  MQ.new.queue('every second').bind(amq.fanout('clock')).subscribe{ |time|
    log 'every second', :received, Marshal.load(time)
  }

  MQ.new.queue('every 5 seconds').bind(amq.fanout('clock')).subscribe{ |time|
    time = Marshal.load(time)
    log 'every 5 seconds', :received, time if time.strftime('%S').to_i%5 == 0
  }

}

__END__

[Thu Jul 17 15:40:03 -0700 2008, :publishing, "time", Thu Jul 17 15:40:03 -0700 2008]
[Thu Jul 17 15:40:03 -0700 2008, "every second", :received, Thu Jul 17 15:40:03 -0700 2008]

[Thu Jul 17 15:40:05 -0700 2008, :publishing, "time", Thu Jul 17 15:40:05 -0700 2008]
[Thu Jul 17 15:40:05 -0700 2008, "every second", :received, Thu Jul 17 15:40:05 -0700 2008]
[Thu Jul 17 15:40:05 -0700 2008, "every 5 seconds", :received, Thu Jul 17 15:40:05 -0700 2008]

[Thu Jul 17 15:40:06 -0700 2008, :publishing, "time", Thu Jul 17 15:40:06 -0700 2008]
[Thu Jul 17 15:40:06 -0700 2008, "every second", :received, Thu Jul 17 15:40:06 -0700 2008]

[Thu Jul 17 15:40:07 -0700 2008, :publishing, "time", Thu Jul 17 15:40:07 -0700 2008]
[Thu Jul 17 15:40:07 -0700 2008, "every second", :received, Thu Jul 17 15:40:07 -0700 2008]

[Thu Jul 17 15:40:08 -0700 2008, :publishing, "time", Thu Jul 17 15:40:08 -0700 2008]
[Thu Jul 17 15:40:08 -0700 2008, "every second", :received, Thu Jul 17 15:40:08 -0700 2008]

[Thu Jul 17 15:40:09 -0700 2008, :publishing, "time", Thu Jul 17 15:40:09 -0700 2008]
[Thu Jul 17 15:40:09 -0700 2008, "every second", :received, Thu Jul 17 15:40:09 -0700 2008]

[Thu Jul 17 15:40:10 -0700 2008, :publishing, "time", Thu Jul 17 15:40:10 -0700 2008]
[Thu Jul 17 15:40:10 -0700 2008, "every second", :received, Thu Jul 17 15:40:10 -0700 2008]
[Thu Jul 17 15:40:10 -0700 2008, "every 5 seconds", :received, Thu Jul 17 15:40:10 -0700 2008]

[Thu Jul 17 15:40:11 -0700 2008, :publishing, "time", Thu Jul 17 15:40:11 -0700 2008]
[Thu Jul 17 15:40:11 -0700 2008, "every second", :received, Thu Jul 17 15:40:11 -0700 2008]