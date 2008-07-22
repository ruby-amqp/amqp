require 'rubygems'
require 'eventmachine'

# helper to fork off EM reactors
def EM.fork num = 1, &blk
  unless @forks
    trap('CHLD'){
      pid = Process.wait
      p [:pid, pid, :died]
      blk = @forks.delete(pid)
      EM.fork(1, &blk)
    }
    trap('EXIT'){
      p [:pid, Process.pid, :exit]
      @forks.keys.each{ |pid|
        p [:pid, Process.pid, :killing, pid]
        Process.kill('USR1', pid)
      }
    }
  end

  @forks ||= {}

  num.times do
    pid = EM.fork_reactor do
      p [:pid, Process.pid, :started]

      trap('USR1'){ EM.stop_event_loop }
      trap('EXIT'){}

      p [:pid, Process.pid, :reactor, :starting]
      blk.call
      p [:pid, Process.pid, :reactor, :stopped]
    end

    @forks[pid] = blk
    p [:children, EM.forks]
  end
end
def EM.forks
  @forks.keys
end

EM.run{
  p [:parent, Process.pid]
  EM.fork(2){
    EM.add_periodic_timer(1) do
      p [:fork, Process.pid, :ping]
    end
  }
}

p 'original reactor stopped'