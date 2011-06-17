# encoding: utf-8
require 'spec_helper'


describe "When queue has no consumers" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_timeout 1.5

  amqp_before do
    @producer_channel    = AMQP::Channel.new
    @consumer_channel    = AMQP::Channel.new
  end

  # ...


  #
  # Examples
  #

  context "and message is published as :immediate" do
    it "that message is returned to the publisher" do
      exchange = @producer_channel.fanout("amq.fanout")
      queue    = @consumer_channel.queue("", :exclusive => true)

      exchange.on_return do |basic_return, metadata, payload|
        done if payload == "immediate message body"
      end

      queue.bind(exchange) do
        exchange.publish "immediate message body", :immediate => true
      end
    end
  end



  context "and message is published as non :immediate" do
    it "that message is dropped" do
      exchange = @producer_channel.fanout("amq.fanout")
      queue    = @consumer_channel.queue("", :exclusive => true)

      exchange.on_return do |basic_return, metadata, payload|
        fail "Should not happen"
      end

      queue.bind(exchange) do
        exchange.publish "non-immediate message body", :immediate => false
      end

      done(1.0)
    end
  end
end # describe
