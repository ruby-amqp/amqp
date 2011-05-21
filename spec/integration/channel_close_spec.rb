# encoding: utf-8

require "spec_helper"

describe AMQP::Channel, "#close(&callback)" do
  include EventedSpec::AMQPSpec

  it "takes a callback which will run when we get back Channel.Close-Ok" do
    @events = []

    AMQP::Channel.new do |ch|
      @events << :open_ok
      ch.close do |channel, close_ok|
        @events << :close_ok
      end
    end

    done(0.3) {
      @events.should == [:open_ok, :close_ok]
    }
  end
end
