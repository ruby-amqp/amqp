require 'spec_helper'
require 'amqp_helper'

describe 'MQ', 'class object' do

  #
  # Environment
  #

  subject { MQ }

  its(:logging) { should be_false }


  #
  # Examples
  #

  describe '.logging=' do
    it 'is independent from AMQP.logging' do
      AMQP.logging = true
      MQ.logging.should be_false
      MQ.logging = false
      AMQP.logging.should == true


      AMQP.logging = false
      MQ.logging = true
      AMQP.logging.should be_false
      MQ.logging = false
    end # it
  end # .logging=
end # describe 'MQ class object'
