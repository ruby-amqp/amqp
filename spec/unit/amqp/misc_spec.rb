# encoding: utf-8

require 'spec_helper'
require 'amqp_helper'

describe 'AMQP', 'class object' do

  #
  # Environment
  #

  subject { AMQP }

  its(:logging) { should be_false }


  #
  # Examples
  #

  describe '.logging=' do
    it 'is independent from AMQP.logging' do
      AMQP.logging = true
      AMQP::Channel.logging.should be_false
      AMQP::Channel.logging = false
      AMQP.logging.should == true


      AMQP.logging = false
      AMQP::Channel.logging = true
      AMQP.logging.should be_false
      AMQP::Channel.logging = false
    end # it
  end # .logging=
end # describe 'AMQP class'
