$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

def EM.fork &blk
  raise if reactor_running?

  unless @forks
    at_exit{
      @forks.each{ |pid| Process.kill('KILL', pid) }
    }
  end

  (@forks ||= []) << Kernel.fork do
    EM.run(&blk)
  end
end

def log *args
  p args
end

# MQ.logging = true

# worker

  workers = ARGV[0] ? (Integer(ARGV[0]) rescue 2) : 2

  workers.times do
    EM.fork{
      log "prime checker", Process.pid, :started

      class Fixnum
        def prime?
          ('1' * self) !~ /^1?$|^(11+?)\1+$/
        end
      end

      MQ.queue('prime checker').subscribe{ |info, num|
        log "prime checker #{Process.pid}", :prime?, num
        if Integer(num).prime?
          MQ.queue(info.reply_to).publish(num, :reply_to => Process.pid)
        end
      }
    }
  end

# controller

  EM.fork{
    MQ.queue('prime collector').subscribe{ |info, prime|
      log 'prime collector', :received, prime, :from, info.reply_to
      (@primes ||= []) << Integer(prime)
    }

    i = 1
    EM.add_periodic_timer(0.01) do
      MQ.queue('prime checker').publish(i.to_s, :reply_to => 'prime collector')
      if i == 50
        Process.kill('KILL', Process.ppid)
        EM.stop_event_loop
      end
      i += 1
    end
  }

# sleep until killed
  sleep