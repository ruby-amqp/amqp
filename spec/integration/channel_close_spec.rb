# encoding: utf-8

require "spec_helper"

describe AMQP, "#close(&callback)" do
  include EventedSpec::AMQPSpec

  default_timeout 5

  it "takes a callback which will run when we get back Channel.Close-Ok" do
    AMQP::Channel.new.close do |amq|
      done
    end
  end
end
