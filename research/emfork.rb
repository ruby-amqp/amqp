require 'rubygems'
require 'eventmachine'

# helper to fork off EM reactors
def EM.fork num = 1, &blk
  raise 'Cannot fork while reactor is running' if reactor_running?

  unless @forks
    trap('CHLD'){
      pid = Process.wait
      p [:pid, pid, :died]
      blk = @forks.delete(pid)
      EM.fork(1, &blk)
    }
    at_exit{
      p [:pid, Process.pid, :exit, is_fork?]
      @forks.keys.each{ |pid|
        p [:pid, Process.pid, :killing, pid]
        Process.kill('USR1', pid)
      } unless is_fork?
    }
  end

  @forks ||= {}

  num.times do
    pid = Kernel.fork do
      def EM.is_fork?() true end
      p [:pid, Process.pid, :started, is_fork?]
      trap('USR1'){ EM.stop_event_loop }
      EM.run(&blk)
      exit
    end

    @forks[pid] = blk
  end
end
def EM.is_fork?() false end
def EM.forks
  @forks.keys
end

p [:parent, Process.pid]
EM.fork(2){}
p [:children, EM.forks]
Process.wait
# EM.run{}