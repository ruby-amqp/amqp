# encoding: utf-8

require File.expand_path("../spec_helper", __FILE__)

describe MQ, "#close(&callback)" do
  include AMQP::EMSpec

  default_timeout 5

  it "takes a callback which will run when we get back Channel.Close-Ok" do
    MQ.new.close do |amq|
      done
    end
  end
end
