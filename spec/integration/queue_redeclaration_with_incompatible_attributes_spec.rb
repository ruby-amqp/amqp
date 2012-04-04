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
      { :durable => false, :exclusive => true, :auto_delete => true, :arguments => {}, :passive => false }
    }
    let(:different_options) {
      { :durable => true, :exclusive => true, :auto_delete => true, :arguments => {}, :passive => false}
    }
    let(:irrelevant_different_options) {
      { :durable => false, :exclusive => true, :auto_delete => true, :arguments => {}, :passive => false, :header => {:random => 'stuff' } }
    }


    it "should raise AMQP::IncompatibleOptionsError for incompatable options" do
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

    it "should not raise AMQP::IncompatibleOptionsError for irrelevant options" do
      channel = AMQP::Channel.new
      channel.on_error do |ch, close|
        @callback_fired = true
      end

      channel.queue(name, options)
      expect {
        channel.queue(name, irrelevant_different_options)
      }.to_not raise_error(AMQP::IncompatibleOptionsError)
      done
    end
  end
end # describe AMQP
