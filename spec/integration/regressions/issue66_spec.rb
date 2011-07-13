# encoding: utf-8

require "spec_helper"

describe "Immediate disconnection" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper


  after :all do
    done
  end

  it "succeeds" do
    c = AMQP.connect
    c.disconnect {
      done
    }
  end # it
end # describe "Authentication attempt"
