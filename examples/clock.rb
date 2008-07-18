$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

EM.run{

  def log *args
    p args
  end

  # AMQP.logging = true

  EM.add_periodic_timer(1){
    puts

    log :publishing, time = Time.now
    MQ.new.fanout('clock').publish(Marshal.dump(time))
  }

  MQ.new.queue('every second').bind('clock').subscribe{ |time|
    log 'every second', :received, Marshal.load(time)
  }

  MQ.new.queue('every 5 seconds').bind('clock').subscribe{ |time|
    time = Marshal.load(time)
    log 'every 5 seconds', :received, time if time.strftime('%S').to_i%5 == 0
  }

}

__END__

[:publishing, Thu Jul 17 20:14:00 -0700 2008]
["every 5 seconds", :received, Thu Jul 17 20:14:00 -0700 2008]
["every second", :received, Thu Jul 17 20:14:00 -0700 2008]

[:publishing, Thu Jul 17 20:14:01 -0700 2008]
["every second", :received, Thu Jul 17 20:14:01 -0700 2008]

[:publishing, Thu Jul 17 20:14:02 -0700 2008]
["every second", :received, Thu Jul 17 20:14:02 -0700 2008]

[:publishing, Thu Jul 17 20:14:03 -0700 2008]
["every second", :received, Thu Jul 17 20:14:03 -0700 2008]

[:publishing, Thu Jul 17 20:14:04 -0700 2008]
["every second", :received, Thu Jul 17 20:14:04 -0700 2008]

[:publishing, Thu Jul 17 20:14:05 -0700 2008]
["every 5 seconds", :received, Thu Jul 17 20:14:05 -0700 2008]
["every second", :received, Thu Jul 17 20:14:05 -0700 2008]

[:publishing, Thu Jul 17 20:14:06 -0700 2008]
["every second", :received, Thu Jul 17 20:14:06 -0700 2008]
