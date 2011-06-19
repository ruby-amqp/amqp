# encoding: utf-8

require 'spec_helper'

describe "Headers exchange" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 2

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
    @channel.queue("", :auto_delete => true).bind(exchange, :arguments => { :os => 'linux' }).subscribe do |metadata, payload|
      any_linux_messages << [metadata, payload]
    end

    osx_or_octocore_messages = []
    @channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'any', :os => 'macosx', :cores => 8 }).subscribe do |metadata, payload|
      osx_or_octocore_messages << [metadata, payload]
    end


    EventMachine.add_timer(0.5) do
      exchange.publish "For linux/IA64",   :headers => { :arch => "IA64", :os => 'linux' }
      exchange.publish "For linux/x86",   :headers => { :arch => "x86", :os => 'linux' }
      exchange.publish "For any linux",   :headers => { :os => 'linux'  }
      exchange.publish "For OS X",        :headers => { :os => 'macosx' }
      exchange.publish "For solaris/IA64", :headers => { :os => 'solaris', :arch => 'IA64' }
      exchange.publish "For ocotocore",   :headers => { :cores => 8  }
    end

    done(1.0) {
      linux_and_ia64_messages.size.should == 1
      linux_and_x86_messages.size.should == 1
      any_linux_messages.size.should == 3
      osx_or_octocore_messages.size.should == 2
    }
  end
end
