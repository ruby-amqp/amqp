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

      p [:reactor_running, EM.reactor_running?]
      if EM.reactor_running?
        EM.stop_event_loop
        EM.release_machine
      end
      # EM doesn't reset reactor_running
      def EM.reactor_running?
        @reactor_running = false
      end
      p [:reactor_running, EM.reactor_running?]

      p 'starting new reactor'
      EM.run(&blk)
      p 'new reactor stopped'
    end

    @forks[pid] = blk
    p [:children, EM.forks]
  end
end
def EM.is_fork?() false end
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

# Process.wait
# EM.run{}
p 'original reactor stopped'