$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

class Logger
  def initialize *args, &block
    opts = args.pop if args.last.is_a? Hash
    opts ||= {}
    printer(block) if block
    @log = []
    @tags = ([:timestamp] + args).uniq
  end

  def log severity, *args
    opts = args.pop if args.last.is_a? Hash and args.size != 1
    opts ||= {}
    data = args.shift

    data = {:type => :exception,
            :name => data.class.to_s.intern,
            :backtrace => data.backtrace,
            :message => data.message} if data.is_a? Exception
        
    (@tags + args).each do |tag|
      tag = tag.to_sym
      case tag
      when :timestamp
        opts.update :timestamp => Time.now.to_i
      when :hostname
        @hostname ||= { :hostname => `hostname`.strip }
        opts.update @hostname
      when :process
        @process_id ||= { :process_id => Process.pid,
                          :process_name => $0,
                          :process_parent_id => Process.ppid,
                          :thread_id => Thread.current.object_id }
        opts.update :process => @process_id
      else
        (opts[:tags] ||= []) << tag
      end
    end
    
    opts.update(:severity => severity,
                :data => data)
    
    print(opts)
    MQ.queue('logger', :durable => true).publish(Marshal.dump(opts), :persistent => true)
    opts
  end
  alias :method_missing :log

  def print data = nil, &block
    if block
      @printer = block
    elsif data.is_a? Proc
      @printer = data
    elsif @printer and data
      @printer.call(data)
    else
      @printer
    end
  end
  alias :printer :print
end

EM.run{
  # AMQP.logging = true
  # MQ.logging = true

  if ARGV[0] == 'server'

    MQ.queue('logger', :durable => true).subscribe{|msg|
      msg = Marshal.load(msg)
      require 'pp'
      pp(msg)
      puts
    }
    
  else

    log = Logger.new
    log.debug 'its working!'
    
    log = Logger.new do |msg|
      require 'pp'
      pp msg
      puts
    end

    log.info '123'
    log.debug [1,2,3]
    log.debug :one => 1, :two => 2
    log.error Exception.new('123')

    log.info '123', :process_id => Process.pid
    log.info '123', :process
    log.debug 'login', :session => 'abc', :user => 123

    log = Logger.new(:webserver, :timestamp, :hostname, &log.printer)
    log.info 'Request for /', :GET, :session => 'abc'

    AMQP.stop

  end
}

__END__

{:data=>"123", :timestamp=>1216846102, :severity=>:info}

{:data=>[1, 2, 3], :timestamp=>1216846102, :severity=>:debug}

{:data=>
  {:type=>:exception, :name=>:Exception, :message=>"123", :backtrace=>nil},
 :timestamp=>1216846102,
 :severity=>:error}

{:data=>"123", :timestamp=>1216846102, :process_id=>1814, :severity=>:info}

{:process=>
  {:thread_id=>109440,
   :process_id=>1814,
   :process_name=>"/Users/aman/code/amqp/examples/logger.rb",
   :process_parent_id=>1813},
 :data=>"123",
 :timestamp=>1216846102,
 :severity=>:info}

{:session=>"abc",
 :data=>"login",
 :timestamp=>1216846102,
 :severity=>:debug,
 :user=>123}

{:session=>"abc",
 :tags=>[:webserver, :GET],
 :data=>"Request for /",
 :timestamp=>1216846102,
 :severity=>:info,
 :hostname=>"gc"}
