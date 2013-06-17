# encoding: utf-8

require 'spec_helper'

describe AMQP do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 5


  #
  # Examples
  #


  context "when queue is redeclared with different attributes across two channels" do
    let(:name)              { "amqp-gem.nondurable.queue" }
    let(:options)           {
      { :durable => false, :passive => false }
    }
    let(:different_options) {
      { :durable => true, :passive => false }
    }


    it "should trigger channel-level #on_error callback" do
      @channel = AMQP::Channel.new
      @channel.on_error do |ch, close|
        puts "This should never happen"
      end
      @q1 = @channel.queue(name, options)

      # Small delays to ensure the order of execution
      delayed(0.1) {
        @other_channel = AMQP::Channel.new
        @other_channel.on_error do |ch, close|
          @callback_fired = true
        end
        puts "other_channel.id = #{@other_channel.id}"
        @q2 = @other_channel.queue(name, different_options)
      }

      delayed(0.3) {
        @q2.delete
      }

      done(0.4) {
        @callback_fired.should be_true
        # looks like there is a difference between platforms/machines
        # so check either one. MK.
        @other_channel.closed?.should be_true
      }
    end
  end
end # describe AMQP
