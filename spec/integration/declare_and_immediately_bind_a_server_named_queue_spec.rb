# encoding: utf-8

require 'spec_helper'

describe "Server-named", AMQP::Queue do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 2


  #
  # Examples
  #


  context "bound to a pre-defined exchange" do
    it "delays binding until after queue.declare-ok arrives" do
      mailbox  = []
      channel  = AMQP::Channel.new
      exchange = channel.fanout("amq.fanout")
      input    = "Independencia de resolución, ¿una realidad en Mac OS X Lion?"

      channel.queue("", :auto_delete => true).bind(exchange).subscribe do |header, body|
        mailbox << body
      end

      delayed(0.5) {
        exchange.publish(input)
      }

      done(1.0) {
        mailbox.size.should == 1
      }
    end
  end


  context "bound to a pre-defined exchange" do
    it "delays binding until after queue.declare-ok arrives" do
      mailbox  = []
      channel  = AMQP::Channel.new
      exchange = channel.fanout("amqpgem.examples.exchanges.fanout", :durable => false)
      input    = "Just send me already"

      channel.queue("", :auto_delete => true).bind(exchange).subscribe do |header, body|
        mailbox << body
      end

      delayed(0.5) {
        exchange.publish(input)
      }

      done(1.0) {
        mailbox.size.should == 1
      }
    end
  end
end
