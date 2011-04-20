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

  context "when queue is redeclared with different attributes" do
    let(:name)              { "amqp-gem.nondurable.queue" }
    let(:options)           {
      { :durable => false, :passive => false }
    }
    let(:different_options) {
      { :durable => true, :passive => false}
    }


    it "should raise AMQP::IncompatibleOptionsError" do
      channel = AMQP::Channel.new
      channel.on_error do |ch, close|
        @callback_fired = true
      end

      channel.queue(name, options)
      expect {
        channel.queue(name, different_options)
      }.to raise_error(AMQP::IncompatibleOptionsError)

      done
    end
  end
end # describe AMQP
