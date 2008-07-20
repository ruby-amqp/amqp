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
      @primes ||= []
      @primes << num if prime
      EM.stop_event_loop if @primes.size == 669
    }

  end
  
}

__END__

$ uname -a
Linux gc 2.6.24-ARCH #1 SMP PREEMPT Sun Mar 30 10:50:22 CEST 2008 x86_64 Intel(R) Xeon(R) CPU X3220 @ 2.40GHz GenuineIntel GNU/Linux

$ cat /proc/cpuinfo | grep processor | wc -l
4

$ time ruby primes.rb >/dev/null

real	0m17.985s
user	0m4.790s
sys	0m0.053s

$ time ruby primes.rb 2 >/dev/null

real	0m11.370s
user	0m4.790s
sys	0m0.083s

$ time ruby primes.rb 4 >/dev/null

real	0m10.091s
user	0m4.963s
sys	0m0.080s

$ time ruby primes.rb 8 >/dev/null

real	0m9.551s
user	0m5.173s
sys	0m0.137s

$ time ruby primes.rb 16 >/dev/null

real	0m8.708s
user	0m4.836s
sys	0m0.103s