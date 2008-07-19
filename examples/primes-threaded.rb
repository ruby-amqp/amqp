$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

def log *args
  p args
end

# MQ.logging = true

EM.run{

  # worker

  log "prime checker", Process.pid, :started

  class Fixnum
    def prime?
      ('1' * self) !~ /^1?$|^(11+?)\1+$/
    end
  end

  MQ.queue('prime checker').subscribe{ |info, num|
    EM.defer(proc{

      log "prime checker #{Process.pid}-#{Thread.current.object_id}", :prime?, num
      if Integer(num).prime?
        MQ.queue(info.reply_to).publish(num, :reply_to => "#{Process.pid}-#{Thread.current.object_id}")
      end
      
    })
  }

  # controller

  MQ.queue('prime collector').subscribe{ |info, prime|
    log 'prime collector', :received, prime, :from, info.reply_to
    (@primes ||= []) << Integer(prime)
  }

  i = 1
  EM.add_periodic_timer(0.01) do
    MQ.queue('prime checker').publish(i.to_s, :reply_to => 'prime collector')
    EM.stop_event_loop if i == 50
    i += 1
  end

}