# encoding: utf-8

require "spec_helper"

describe AMQP::Session, "#close(&callback)" do
  include EventedSpec::AMQPSpec

  it "takes a callback which will run when we get back connection.close-ok" do
    @events = []

    c = AMQP.connect do |session|
      @events << :open_ok
      session.close do |session, close_ok|
        @events << :close_ok
      end
    end

    done(0.3) {
      c.should be_closed
      @events.should == [:open_ok, :close_ok]
    }
  end
end
