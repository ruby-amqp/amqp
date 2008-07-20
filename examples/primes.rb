$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

MAX = 5000

def EM.fork num = 1, &blk
  raise if reactor_running?

  unless @forks
    at_exit{
      @forks.each{ |pid|
        begin
          Process.kill('USR1', pid)
        rescue Errno::ESRCH
        end
      }
    }
  end

  num.times do
    (@forks ||= []) << Kernel.fork do
      trap('USR1'){ EM.stop_event_loop }

      def MQ.id
        Thread.current[:mq_id] ||= "#{`hostname`.strip}-#{Process.pid}-#{Thread.current.object_id}"
      end

      EM.run(&blk)
    end
  end
end

def log *args
  p args
end

workers = ARGV[0] ? (Integer(ARGV[0]) rescue 1) : 1

EM.fork(workers) do

  log MQ.id, :started

  class Fixnum
    def prime?
      ('1' * self) !~ /^1?$|^(11+?)\1+$/
    end
  end

  class PrimeChecker
    def is_prime? number
      log "prime checker #{MQ.id}", :prime?, number
      number.prime?
    end
  end

  MQ.rpc('prime checker', PrimeChecker.new)

end

EM.run{
  
  prime_checker = MQ.rpc('prime checker')

  (1..MAX).each do |num|
    log :checking, num

    prime_checker.is_prime?(num) { |prime|
      log :prime?, num, prime
      (@primes ||= []) << num if prime
      EM.stop_event_loop if num == MAX
    }

  end
  
}

__END__

on a first gen core duo macbook:

  $ time ruby primes.rb >/dev/null

  real	0m24.375s
  user	0m10.117s
  sys	0m0.242s

  $ time ruby primes.rb 2 >/dev/null

  real	0m16.406s
  user	0m8.393s
  sys	0m0.209s