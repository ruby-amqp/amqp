# encoding: utf-8

require 'spec_helper'

describe AMQP do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 5

  amqp_before do
    @channel = AMQP::Channel.new
  end


  #
  # Examples
  #


  describe ".channel" do
    it 'gives each thread a separate channel' do
      pending 'This is not implemented in current lib'
      module AMQP
        @@cur_channel = 0
      end

      described_class.channel.should == 1

      Thread.new { described_class.channel }.value.should == 2
      Thread.new { described_class.channel }.value.should == 3
      done
    end
  end
end # describe AMQP
