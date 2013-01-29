# encoding: utf-8

require 'spec_helper'

describe "AMQP queue redeclaration with different attributes" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 5


  #
  # Examples
  #

  context "when :durable value is different" do
    let(:name)              { "amqp-gem.nondurable.queue" }
    let(:options)           {
      { :durable => false, :exclusive => true, :auto_delete => true, :arguments => {}, :passive => false }
    }
    let(:different_options) {
      { :durable => true, :exclusive => true, :auto_delete => true, :arguments => {}, :passive => false}
    }


    it "should raise AMQP::IncompatibleOptionsError for incompatable options" do
      channel = AMQP::Channel.new
      channel.on_error do |ch, channel_close|
        @error_code = channel_close.reply_code
      end

      channel.queue(name, options)
      expect {
        channel.queue(name, different_options)
      }.to raise_error(AMQP::IncompatibleOptionsError)

      done(0.5) {
        @error_code.should == 406
      }
    end
  end

  context "when :headers are different" do
    let(:name)              { "amqp-gem.nondurable.queue" }
    let(:options)           {
      { :durable => false, :exclusive => true, :auto_delete => true, :arguments => {}, :passive => false }
    }
    let(:different_options) {
      { :durable => false, :exclusive => true, :auto_delete => true, :arguments => {}, :passive => false, :header => {:random => 'stuff' } }
    }

    it "should not raise AMQP::IncompatibleOptionsError for irrelevant options" do
      channel = AMQP::Channel.new
      channel.on_error do |ch, channel_close|
        @error_code = channel_close.reply_code
      end

      channel.queue(name, options)
      expect {
        channel.queue(name, different_options)
      }.to_not raise_error(AMQP::IncompatibleOptionsError)

      done(0.5) {
        @error_code.should == 406
      }
    end
  end
end # describe AMQP
