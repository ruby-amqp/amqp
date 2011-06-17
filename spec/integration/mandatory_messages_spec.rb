# encoding: utf-8
require 'spec_helper'


describe "When exchange a message is published to has no bindings" do

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

  context "and message is published as :mandatory" do
    it "that message is returned to the publisher" do
      exchange = @producer_channel.fanout("amqpgem.examples.mandatory.messages", :auto_delete => true)

      exchange.on_return do |basic_return, metadata, payload|
        done if payload == "mandatory message body"
      end

      exchange.publish "mandatory message body", :mandatory => true
    end
  end



  context "and message is published as non :mandatory" do
    it "that message is dropped" do
      exchange = @producer_channel.fanout("amqpgem.examples.mandatory.messages", :auto_delete => true)

      exchange.on_return do |basic_return, metadata, payload|
        fail "Should not happen"
      end
      exchange.publish "mandatory message body", :mandatory => false

      done(1.0)
    end
  end
end # describe
