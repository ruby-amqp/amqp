$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

# find primes up to
MAX = 5000

# helper to fork off EM reactors
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

# logging
def log *args
  p args
end

# spawn workers
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

# use workers to check which numbers are prime
EM.run{
  
  prime_checker = MQ.rpc('prime checker')

  (1..MAX).each do |num|
    log :checking, num

    prime_checker.is_prime?(num) { |prime|
      log :prime?, num, prime
      EM.stop_event_loop if ((@primes||=[]) << num).size == MAX
    }

  end
  
}

__END__

$ uname -a
Linux gc 2.6.24-ARCH #1 SMP PREEMPT Sun Mar 30 10:50:22 CEST 2008 x86_64 Intel(R) Xeon(R) CPU X3220 @ 2.40GHz GenuineIntel GNU/Linux

$ cat /proc/cpuinfo | grep processor | wc -l
4

$ time ruby primes-simple.rb 

real  0m7.936s
user  0m7.933s
sys 0m0.003s

$ time ruby primes.rb 1 >/dev/null

real  0m18.023s
user  0m4.803s
sys 0m0.053s

$ time ruby primes.rb 2 >/dev/null

real  0m11.501s
user  0m4.756s
sys 0m0.070s

$ time ruby primes.rb 4 >/dev/null

real  0m8.863s
user  0m4.816s
sys 0m0.073s

$ time ruby primes.rb 8 >/dev/null

real  0m8.474s
user  0m4.883s
sys 0m0.093s

$ time ruby primes.rb 16 >/dev/null

real  0m8.614s
user  0m4.856s
sys 0m0.077s

