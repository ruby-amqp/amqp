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

  let(:messages) { (0..99).map {|i| "Message #{i}" } }


  #
  # Examples
  #

  before :each do
    @consumer1_mailbox = []
    @consumer2_mailbox = []
    @consumer3_mailbox = []
  end

  context "with equal prefetch levels" do
    it "have messages distributed to them in the round-robin manner" do
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



  context "with equal prefetch levels and one consumer cancelled mid-flight" do
    it "have messages distributed to them in the round-robin manner" do
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

        consumer2.cancel
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
        @consumer1_mailbox.size.should == 50
        @consumer2_mailbox.size.should == 0
        @consumer3_mailbox.size.should == 50
      }
    end # it
  end # context




  context "with equal prefetch levels and two consumers cancelled mid-flight" do
    it "have messages distributed to the only active consumer" do
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
        queue.unsubscribe

        consumer2.cancel
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
        @consumer1_mailbox.size.should == 100
        @consumer2_mailbox.size.should == 0
        @consumer3_mailbox.size.should == 0
      }
    end # it
  end # context




  context "with equal prefetch levels and ALL consumers cancelled mid-flight" do
    it "returns all immediate messages" do
      @returned_messages = []

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
        queue.unsubscribe

        consumer2.cancel
        consumer1.cancel
      end

      exchange = channel.default_exchange
      exchange.on_return do |basic_return, metadata, payload|
        @returned_messages << payload
      end

      EventMachine.add_timer(1.0) do
        messages.each do |message|
          exchange.publish(message, :immediate => true, :mandatory => true, :routing_key => queue.name)
        end
      end

      done(1.5) {
        @returned_messages.size.should == 100
      }
    end # it
  end # context
end # describe
