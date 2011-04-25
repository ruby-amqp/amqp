# encoding: utf-8

require 'spec_helper'

describe "Server-named", AMQP::Queue do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 5

  amqp_before do
    @channel = AMQP::Channel.new
  end


  #
  # Examples
  #


  it "delays binding until after queue.declare-ok arrives" do
    mailbox  = []
    exchange = @channel.fanout("amq.fanout")
    input    = "Independencia de resolución, ¿una realidad en Mac OS X Lion?"

    @channel.queue("", :auto_delete => true).bind(exchange).subscribe do |header, body|
      mailbox << body
    end

    delayed(0.3) {
      exchange.publish(input)
    }

    done(0.5) {
      mailbox.size.should == 1
    }
  end
end
