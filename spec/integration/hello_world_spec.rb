# encoding: utf-8

require "spec_helper"

describe "A 'Hello, world'-like example with a non-empty message" do

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

    @queue.bind(@exchange, :routing_key => "messages.all")
  end



  it "is delivered" do
    consumer1 = AMQP::Consumer.new(@channel, @queue).consume
    consumer1.on_delivery do |metadata, payload|
      done
    end

    EventMachine.add_timer(0.5) do
      @exchange.publish("Hello!", :routing_key => "messages.all")
    end
  end
end



describe "A 'Hello, world'-like example with a blank message" do

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

    @queue.bind(@exchange, :routing_key => "messages.all")
  end



  it "is delivered" do
    consumer1 = AMQP::Consumer.new(@channel, @queue).consume
    consumer1.on_delivery do |metadata, payload|
      done
    end

    EventMachine.add_timer(0.5) do
      @exchange.publish("", :routing_key => "messages.all")
    end
  end
end