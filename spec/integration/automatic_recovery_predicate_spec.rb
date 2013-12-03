# encoding: utf-8

require "spec_helper"

describe AMQP::Channel, "#auto_recovery" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper


  default_options AMQP_OPTS
  default_timeout 2


  it "switches automatic recovery mode on" do
    ch = AMQP::Channel.new(AMQP.connection)
    ch.auto_recovery.should be_false
    ch.auto_recovery = true
    ch.auto_recovery.should be_true
    ch.auto_recovery = false
    ch.auto_recovery.should be_false

    done
  end
end




describe AMQP::Channel, "options hash" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper


  default_options AMQP_OPTS
  default_timeout 2


  it "can be passed as the 3rd constructor argument" do
    ch = AMQP::Channel.new(AMQP.connection, nil, :auto_recovery => true)
    ch.auto_recovery.should be_true
    ch.auto_recovery = false
    ch.auto_recovery.should be_false

    done
  end


  it "can be passed as the 2nd constructor argument" do
    ch = AMQP::Channel.new(AMQP.connection, :auto_recovery => true)
    ch.auto_recovery.should be_true
    ch.should be_auto_recovering
    ch.auto_recovery = false
    ch.auto_recovery.should be_false
    ch.should_not be_auto_recovering

    done
  end
end
