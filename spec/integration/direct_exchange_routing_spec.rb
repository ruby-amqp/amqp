# encoding: utf-8

require 'spec_helper'

describe "Multiple consumers bound to a queue with the same routing key" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_options AMQP_OPTS
  default_timeout 5

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.on_error do |ch, close|
      raise "Channel-level error!: #{close.inspect}"
    end

    @queue    = @channel.queue("", :auto_delete => true)
    @exchange = @channel.direct("amqpgem.tests.integration.direct.exchange", :auto_delete => true)

    @queue.bind(@exchange, :routing_key => "builds.all")
  end



  it "get messages distributed to them in a round-robin manner" do
    mailbox1  = Array.new
    mailbox2  = Array.new

    consumer1 = AMQP::Consumer.new(@channel, @queue).consume
    consumer2 = AMQP::Consumer.new(@channel, @queue).consume


    consumer1.on_delivery do |metadata, payload|
      mailbox1 << payload
    end
    consumer2.on_delivery do |metadata, payload|
      mailbox2 << payload
    end


    EventMachine.add_timer(0.5) do
      12.times { @exchange.publish(".", :routing_key => "builds.all") }
      12.times { @exchange.publish(".", :routing_key => "all.builds") }
    end

    done(4.5) {
      mailbox1.size.should == 6
      mailbox2.size.should == 6
    }
  end
end




describe "Multiple queues bound to a direct exchange with the same routing key" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_options AMQP_OPTS
  default_timeout 5


  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.on_error do |ch, close|
      raise "Channel-level error!: #{close.inspect}"
    end

    @queue1   = @channel.queue("", :auto_delete => true)
    @queue2   = @channel.queue("", :auto_delete => true)
    @exchange = @channel.direct("amqpgem.tests.integration.direct.exchange", :auto_delete => true)

    @queue1.bind(@exchange, :routing_key => "builds.all")
    @queue2.bind(@exchange, :routing_key => "builds.all")
  end


  it "all get a copy of messages with that routing key" do
    mailbox1  = Array.new
    mailbox2  = Array.new
    mailbox3  = Array.new
    mailbox4  = Array.new


    consumer1 = AMQP::Consumer.new(@channel, @queue1).consume
    consumer2 = AMQP::Consumer.new(@channel, @queue1).consume
    consumer3 = AMQP::Consumer.new(@channel, @queue2).consume
    consumer4 = AMQP::Consumer.new(@channel, @queue2).consume


    consumer1.on_delivery do |metadata, payload|
      mailbox1 << payload
    end
    consumer2.on_delivery do |metadata, payload|
      mailbox2 << payload
    end
    consumer3.on_delivery do |metadata, payload|
      mailbox3 << payload
    end
    consumer4.on_delivery do |metadata, payload|
      mailbox4 << payload
    end


    EventMachine.add_timer(0.5) do
      13.times { @exchange.publish(".", :routing_key => "builds.all") }
      13.times { @exchange.publish(".", :routing_key => "all.builds") }
    end

    done(3.5) {
      mailbox1.size.should == 7
      mailbox2.size.should == 6
      mailbox3.size.should == 7
      mailbox4.size.should == 6
    }
  end
end
