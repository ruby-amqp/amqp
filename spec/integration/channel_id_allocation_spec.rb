# encoding: utf-8

require "spec_helper"

describe AMQP::Channel, "#initialize" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper


  default_options AMQP_OPTS
  default_timeout 3

  it "allocates ids using bitset allocator" do
    ch1 = AMQP::Channel.new
    ch2 = AMQP::Channel.new
    ch3 = AMQP::Channel.new

    ch1.id.should == 1
    ch2.id.should == 2
    ch3.id.should == 3

    ch1.close
    ch2.close

    ch1b = AMQP::Channel.new
    ch2b = AMQP::Channel.new
    ch4  = AMQP::Channel.new

    ch1b.id.should == 1
    ch2b.id.should == 2
    ch4.id.should == 4

    done
  end
end