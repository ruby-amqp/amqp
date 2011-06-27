# -*- coding: utf-8 -*-
require "spec_helper"

describe "Multiple non-exclusive consumers per queue" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper

  default_options AMQP_OPTS
  default_timeout 3


  #
  # Examples
  #

  context "with equal prefetch levels" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "have messages distributed to them in the round-robin manner" do
      @consumer1_mailbox = []
      @consumer2_mailbox = []
      @consumer3_mailbox = []

      channel = AMQP::Channel.new
      channel.on_error do |ch, channel_close|
        raise(channel_close.reply_text)
      end

      queue   = channel.queue("amqpgem.integration.roundrobin.queue1", :auto_delete => true) do
        consumer1 = AMQP::Consumer.new(channel, queue)
        consumer2 = AMQP::Consumer.new(channel, queue, "#{queue.name}-consumer-#{rand}-#{Time.now}", false, true)

        consumer1.consume.on_delivery do |basic_deliver, metadata, payload|
          @consumer1_mailbox << payload
        end

        consumer2.consume(true).on_delivery do |metadata, payload|
          @consumer2_mailbox << payload
        end

        queue.subscribe do |metadata, payload|
          @consumer3_mailbox << payload
        end
      end

      exchange = channel.default_exchange
      exchange.on_return do |basic_return, metadata, payload|
        raise(basic_return.reply_text)
      end

      EventMachine.add_timer(1.0) do
        messages.each do |message|
          exchange.publish(message, :immediate => true, :mandatory => true, :routing_key => queue.name)
        end
      end

      done(1.5) {
        @consumer1_mailbox.size.should == 34
        @consumer2_mailbox.size.should == 33
        @consumer3_mailbox.size.should == 33
      }
    end # it
  end # context
end # describe
