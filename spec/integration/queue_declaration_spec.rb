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

  describe "#queue" do
    context "when queue name is specified" do
      let(:name) { "a queue declared at #{Time.now.to_i}" }

      it "declares a new queue with that name" do
        queue = @channel.queue(name)
        queue.name.should == name
        done
      end

      it "caches that queue" do
        queue = @channel.queue(name)
        @channel.queue(name).object_id.should == queue.object_id
        done
      end
    end # context

    context "when queue name is passed on as an empty string" do
      it "uses server-assigned queue name" do
        @channel.queue("") do |queue, *args|
          queue.name.should_not be_empty
          queue.delete
          done(0.3)
        end
      end
    end # context


    context "when queue is redeclared with different attributes" do
      let(:name) { "amqp-gem.nondurable.queue" }
      let(:options) { {:durable => false, :passive => false} }
      let(:different_options) { {:durable => true, :passive => false} }
      amqp_before do
        @queue       = @channel.queue(name, options)
        delayed(0.25) { @queue.delete }
      end

      context "on the same channel" do
        it "should raise ruby exception" do
          expect {
            @other_queue = @channel.queue(name, different_options)
          }.to raise_error(AMQP::IncompatibleOptionsError)
          @queue.delete
          done(0.2)
        end
      end

      context "on different channels (or even in different processes)" do
        amqp_before { @other_channel = AMQP::Channel.new }

        it "should not raise ruby exception" do
          expect {
            @other_queue = @other_channel.queue(name, different_options)
          }.to_not raise_error
          done
        end

        it "should trigger channel-level #on_error callback" do
          @other_channel.on_error {|*args| @callback_fired = true }
          @other_queue = @other_channel.queue(name, different_options)
          done(0.35) {
            @callback_fired.should be_true
            @other_channel.should be_closed
          }
        end
      end
    end

    context "when passive option is used" do
      context "and queue with given name already exists" do
        it "silently returns" do
          name = "a_new_queue declared at #{Time.now.to_i}"

          original_queue = @channel.queue(name)
          queue          = @channel.queue(name, :passive => true)

          queue.should == original_queue

          done
        end # it
      end

      context "and queue with given name DOES NOT exist" do
        it "raises an exception" do
          pending "Not yet supported"

          expect {
            exchange = @channel.queue("queue declared at #{Time.now.to_i}", :passive => true)
          }.to raise_error

          done
        end # it
      end # context
    end # context




    context "when queue is re-declared with parameters different from original declaration" do
      it "raises an exception" do
        @channel.queue("previously.declared.durable.queue", :durable => true)

        expect {
          @channel.queue("previously.declared.durable.queue", :durable => false)
        }.to raise_error(AMQP::IncompatibleOptionsError)

        done
      end # it
    end # context
  end # describe
end # describe AMQP
