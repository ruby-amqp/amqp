# encoding: utf-8

require "spec_helper"

describe AMQP::Channel, "#close(&callback)" do
  include EventedSpec::AMQPSpec

  it "takes a callback which will run when we get back Channel.Close-Ok" do
    AMQP::Channel.new do |channel, method|
      channel.close do |channel, method|
        done
      end
    end
  end
end
