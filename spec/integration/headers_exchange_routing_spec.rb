# encoding: utf-8

require 'spec_helper'

describe "Headers exchange" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 5

  amqp_before do
    @connection = AMQP.connect
    @channel    = AMQP::Channel.new(@connection)

    @channel.on_error do |ch, channel_close|
      fail "A channel-level exception: #{channel_close.inspect}"
    end
  end

  after(:all) do
    AMQP.cleanup_state
    done
  end


  #
  # Examples
  #

  # it would be following good practices to split this into
  # 2 separate examples but I think this particular example
  # is complete because it demonstrates routing in cases when
  # different queues are bound with x-match = any AND x-match = all. MK.
  it "can route messages based on any or all of N headers" do
    exchange = @channel.headers("amq.match", :durable => true)

    linux_and_ia64_messages = []
    @channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'all', :arch => "IA64", :os => 'linux' }).subscribe do |metadata, payload|
      linux_and_ia64_messages << [metadata, payload]
    end

    linux_and_x86_messages = []
    @channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'all', :arch => "x86", :os => 'linux' }).subscribe do |metadata, payload|
      linux_and_x86_messages << [metadata, payload]
    end

    any_linux_messages = []
    @channel.queue("", :auto_delete => true).bind(exchange, :arguments => { "x-match" => "any", :os => 'linux' }).subscribe do |metadata, payload|
      any_linux_messages << [metadata, payload]
    end

    osx_or_octocore_messages = []
    @channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'any', :os => 'macosx', :cores => 8 }).subscribe do |metadata, payload|
      osx_or_octocore_messages << [metadata, payload]
    end

    riak_messages = []
    @channel.queue("", :auto_delete => true).bind(exchange, :arguments => { "x-match" => "any", :package => { :name => 'riak', :version => '0.14.2' } }).subscribe do |metadata, payload|
      riak_messages << [metadata, payload]
    end


    EventMachine.add_timer(0.5) do
      exchange.publish "For linux/IA64",   :headers => { :arch => "IA64", :os => 'linux' }
      exchange.publish "For linux/x86",    :headers => { :arch => "x86",  :os => 'linux' }
      exchange.publish "For any linux",    :headers => { :os => 'linux' }
      exchange.publish "For OS X",         :headers => { :os => 'macosx' }
      exchange.publish "For solaris/IA64", :headers => { :os => 'solaris', :arch => 'IA64' }
      exchange.publish "For ocotocore",    :headers => { :cores => 8 }

      exchange.publish "For nodes with Riak 0.14.2", :headers => { :package => { :name => 'riak', :version => '0.14.2' } }
    end

    done(4.5) {
      linux_and_ia64_messages.size.should == 1
      linux_and_x86_messages.size.should == 1
      any_linux_messages.size.should == 3
      osx_or_octocore_messages.size.should == 2

      riak_messages.size.should == 1
    }
  end
end





describe "Multiple consumers" do
  include EventedSpec::AMQPSpec
  default_options AMQP_OPTS
  default_timeout 5

  describe "bound to a queue with the same single header" do

    #
    # Environment
    #

    amqp_before do
      @channel   = AMQP::Channel.new
      @channel.on_error do |ch, close|
        raise "Channel-level error!: #{close.inspect}"
      end

      @queue    = @channel.queue("", :auto_delete => true)
      @exchange = @channel.headers("amqpgem.tests.integration.headers.exchange1", :auto_delete => true)

      @queue.bind(@exchange, :arguments => { :slug => "all", "x-match" => "any" })
    end



    it "get messages distributed to them in a round-robin manner" do
      mailbox1  = Array.new
      mailbox2  = Array.new

      consumer1 = AMQP::Consumer.new(@channel, @queue).consume.on_delivery { |metadata, payload| mailbox1 << payload }
      consumer2 = AMQP::Consumer.new(@channel, @queue).consume.on_delivery { |metadata, payload| mailbox2 << payload }


      EventMachine.add_timer(0.5) do
        12.times { @exchange.publish(".", :headers => { :slug => "all" }) }
        12.times { @exchange.publish(".", :headers => { :slug => "rspec" }) }
      end

      done(3.5) {
        mailbox1.size.should == 6
        mailbox2.size.should == 6
      }
    end
  end



  describe "bound to a queue with the same two header & x-match = all" do

    #
    # Environment
    #

    amqp_before do
      @channel   = AMQP::Channel.new
      @channel.on_error do |ch, close|
        raise "Channel-level error!: #{close.inspect}"
      end

      @queue    = @channel.queue("", :auto_delete => true)
      @exchange = @channel.headers("amqpgem.tests.integration.headers.exchange1", :auto_delete => true)

      @queue.bind(@exchange, :arguments => { :slug => "all", :arch => "ia64", 'x-match' => 'all' })
    end


    it "get messages distributed to them in a round-robin manner" do
      mailbox1  = Array.new
      mailbox2  = Array.new

      consumer1 = AMQP::Consumer.new(@channel, @queue).consume.on_delivery { |metadata, payload| mailbox1 << payload }
      consumer2 = AMQP::Consumer.new(@channel, @queue).consume.on_delivery { |metadata, payload| mailbox2 << payload }

      EventMachine.add_timer(0.5) do
        12.times { @exchange.publish(".", :headers => { :slug => "all",   :arch => "ia64" }) }
        12.times { @exchange.publish(".", :headers => { :slug => "rspec", :arch => "ia64" }) }
      end

      done(3.5) {
        mailbox1.size.should == 6
        mailbox2.size.should == 6
      }
    end
  end



  describe "bound to 2 queues with the same two header & x-match = all" do

    #
    # Environment
    #

    amqp_before do
      @channel   = AMQP::Channel.new
      @channel.on_error do |ch, close|
        raise "Channel-level error!: #{close.inspect}"
      end

      @queue1   = @channel.queue("", :auto_delete => true)
      @queue2   = @channel.queue("", :auto_delete => true)
      @exchange = @channel.headers("amqpgem.tests.integration.headers.exchange1", :auto_delete => true)

      args      = { :slug => "all", :arch => "ia64", 'x-match' => 'all' }
      @queue1.bind(@exchange, :arguments => args)
      @queue2.bind(@exchange, :arguments => args)
    end

    it "get messages distributed to both queues, and in a round-robin manner between consumers on one queue" do
      mailbox1  = Array.new
      mailbox2  = Array.new
      mailbox3  = Array.new
      mailbox4  = Array.new

      consumer1 = AMQP::Consumer.new(@channel, @queue1).consume.on_delivery { |metadata, payload| mailbox1 << payload }
      consumer2 = AMQP::Consumer.new(@channel, @queue1).consume.on_delivery { |metadata, payload| mailbox2 << payload }
      consumer3 = AMQP::Consumer.new(@channel, @queue2).consume.on_delivery { |metadata, payload| mailbox3 << payload }
      consumer4 = AMQP::Consumer.new(@channel, @queue2).consume.on_delivery { |metadata, payload| mailbox4 << payload }

      EventMachine.add_timer(0.5) do
        12.times { |i| @exchange.publish("all-#{i}",   :headers => { :slug => "all",   :arch => "ia64" }) }
        16.times { |i| @exchange.publish("rspec-#{i}", :headers => { :slug => "rspec", :arch => "ia64" }) }
      end

      done(3.5) {
        mailbox1.size.should == 6
        mailbox1.should == ["all-0", "all-2", "all-4", "all-6", "all-8", "all-10"]

        mailbox2.size.should == 6
        mailbox2.should == ["all-1", "all-3", "all-5", "all-7", "all-9", "all-11"]

        mailbox3.size.should == 6
        mailbox4.size.should == 6
      }
    end
  end




  describe "bound to a queue with the same two header & x-match = any" do

    #
    # Environment
    #

    amqp_before do
      @channel   = AMQP::Channel.new
      @channel.on_error do |ch, close|
        raise "Channel-level error!: #{close.inspect}"
      end

      @queue    = @channel.queue("", :auto_delete => true)
      @exchange = @channel.headers("amqpgem.tests.integration.headers.exchange1", :auto_delete => true)

      @queue.bind(@exchange, :arguments => { :slug => "all", :arch => "ia64", 'x-match' => 'any' })
    end

    it "get messages distributed to them in a round-robin manner" do
      mailbox1  = Array.new
      mailbox2  = Array.new

      consumer1 = AMQP::Consumer.new(@channel, @queue).consume.on_delivery { |metadata, payload| mailbox1 << payload }
      consumer2 = AMQP::Consumer.new(@channel, @queue).consume.on_delivery { |metadata, payload| mailbox2 << payload }

      EventMachine.add_timer(0.5) do
        12.times { @exchange.publish(".", :headers => { :slug => "all",   :arch => "ia64" }) }
        4.times  { @exchange.publish(".", :headers => { :slug => "rspec", :arch => "ia64" }) }
      end

      done(3.5) {
        mailbox1.size.should == 8
        mailbox2.size.should == 8
      }
    end
  end
end
