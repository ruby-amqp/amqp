# -*- coding: utf-8 -*-
require "spec_helper"

require "amqp/extensions/rabbitmq"


describe "confirm.select" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper

  default_options AMQP_OPTS
  default_timeout 3

  amqp_before do
    @channel = AMQP::Channel.new
  end


  context "with :nowait attribute off" do
    it "results in a confirm.select-ok response" do
      @channel.confirm_select do |select_ok|
        done
      end
    end
  end


  context "with :nowait attribute set" do
    it "results in NOT confirm.select-ok response" do
      lambda do
        @channel.confirm_select(:nowait => true) do
          fail "Should never be called"
        end
      end.should raise_error(ArgumentError, /makes no sense/)

      @channel.confirm_select(:nowait => true)

      done(0.5)
    end
  end
end




describe "Publisher confirmation(s)" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper

  default_options AMQP_OPTS
  default_timeout 3


  amqp_before do
    @channel1 = AMQP::Channel.new
    @channel2 = AMQP::Channel.new
  end


  context "when messages are transient" do
    context "and routable" do
      it "are confirmed as soon as they arrive on all the queues they were routed to" do
        events   = Array.new

        exchange = @channel2.fanout("amqpgem.tests.fanout1", :auto_delete => true)
        queue    = @channel1.queue("", :auto_delete => true).bind(exchange).subscribe do |metadata, payload|
          events << :basic_delivery
        end

        @channel2.confirm_select
        @channel2.on_ack do |basic_ack|
          events << :basic_ack
        end
        exchange.on_return do |basic_return, metadata, payload|
          fail "Should never happen"
        end

        EventMachine.add_timer(0.5) do
          exchange.publish("Hi", :persistent => false, :mandatory => true)
        end

        done(1.0) do
          events.should include(:basic_ack)
          events.should include(:basic_delivery)
        end
      end
    end


    context "and can be delivered immediately" do
      it "are confirmed as soon as they arrive on all the queues they were routed to" do
        events   = Array.new

        exchange = @channel2.fanout("amqpgem.tests.fanout2", :auto_delete => true)
        queue    = @channel1.queue("", :auto_delete => true).bind(exchange).subscribe do |metadata, payload|
          events << :basic_delivery
        end

        @channel2.confirm_select
        @channel2.on_ack do |basic_ack|
          events << :basic_ack
        end
        exchange.on_return do |basic_return, metadata, payload|
          fail "Should never happen"
        end

        EventMachine.add_timer(0.5) do
          exchange.publish("Hi", :persistent => false, :immediately => true)
        end

        done(1.0) do
          events.should include(:basic_ack)
          events.should include(:basic_delivery)
        end
      end
    end



    context "and NOT routable" do
      it "are delivered immediately after basic.return" do
        events   = Array.new

        queue    = @channel1.queue("", :auto_delete => true)
        exchange = @channel2.fanout("amqpgem.tests.fanout3", :auto_delete => true)

        @channel2.confirm_select
        @channel2.on_ack do |basic_ack|
          events << :basic_ack
        end
        exchange.on_return do |basic_return, metadata, payload|
          events << :basic_return
        end

        EventMachine.add_timer(0.5) do
          exchange.publish("Hi", :persistent => false, :mandatory => true)
        end

        done(1.0) { events.should == [:basic_return, :basic_ack] }
      end
    end



    context "and CAN NOT be delivered immediately" do
      it "are delivered immediately after basic.return" do
        events   = Array.new

        queue    = @channel1.queue("", :auto_delete => true)
        exchange = @channel2.fanout("amqpgem.tests.fanout4", :auto_delete => true)

        @channel2.confirm_select
        @channel2.on_ack do |basic_ack|
          events << :basic_ack
        end
        exchange.on_return do |basic_return, metadata, payload|
          events << :basic_return
        end

        EventMachine.add_timer(0.5) do
          exchange.publish("Hi", :persistent => false, :mandatory => true)
        end

        done(1.0) { events.should == [:basic_return, :basic_ack] }
      end
    end

  end
end
