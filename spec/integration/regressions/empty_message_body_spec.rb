# encoding: utf-8

require "spec_helper"

describe "Messages with empty bodies" do

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



  it "can be mixed with any other messages" do
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
      12.times { @exchange.publish("",  :routing_key => "builds.all") }
      12.times { @exchange.publish(".", :routing_key => "all.builds") }
      12.times { @exchange.publish("",  :routing_key => "all.builds") }
    end

    done(1.5) {
      mailbox1.size.should == 6
      mailbox2.size.should == 6
    }
  end
end
