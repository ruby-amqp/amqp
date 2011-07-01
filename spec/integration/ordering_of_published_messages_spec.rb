# -*- coding: utf-8 -*-

require 'spec_helper'

describe "1000 AMQP messages" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_options AMQP_OPTS
  default_timeout 3


  before :all do
    @list = Range.new(0, 1000, true).to_a
  end


  context "published and received on the same channel" do
    amqp_before do
      @channel   = AMQP::Channel.new
      @channel.on_error do |ch, close|
        raise "Channel-level error!: #{close.inspect}"
      end

      @queue = @channel.queue("amqpgem.tests.integration.queue1", :auto_delete => true)
    end

    #
    # Examples
    #

    it "are received on the same channel in the order of publishing" do
      received = []

      @queue.subscribe do |metadata, payload|
        received << payload.to_i
      end

      EventMachine.add_timer(0.3) do
        @list.each { |i| @channel.default_exchange.publish(i.to_s, :routing_key => @queue.name) }
      end

      done(1.0) {
        received.size.should == 1000
        received.first.should == 0
        received.last.should == 999

        received.should == @list
      }
    end
  end


  context "published on two different channels" do
    amqp_before do
      @channel1   = AMQP::Channel.new
      @channel2   = AMQP::Channel.new

      @channel1.on_error do |ch, close|
        raise "Channel-level error!: #{close.inspect}"
      end
      @channel2.on_error do |ch, close|
        raise "Channel-level error!: #{close.inspect}"
      end

      @queue = @channel1.queue("amqpgem.tests.integration.queue1", :auto_delete => true)
    end

    #
    # Examples
    #

    it "are received on the same channel in the order of publishing" do
      received = []

      @queue.subscribe do |metadata, payload|
        received << payload.to_i
      end

      EventMachine.add_timer(0.3) do
        @list.each { |i| @channel2.default_exchange.publish(i.to_s, :routing_key => @queue.name) }
      end

      done(1.0) {
        received.size.should == 1000
        received.first.should == 0
        received.last.should == 999

        received.should == @list
      }
    end
  end
end # describe
