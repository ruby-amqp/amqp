# encoding: utf-8

require 'spec_helper'

describe MQ do

  #
  # Environment
  #

  include AMQP::Spec

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
          done
        end
      end
    end # context




    context "when passive option is used" do
      context "and exchange with given name already exists" do
        it "silently returns" do
          name = "a_new_queue declared at #{Time.now.to_i}"

          original_exchange = @channel.queue(name)
          exchange          = @channel.queue(name, :passive => true)

          exchange.should == original_exchange

          done
        end # it
      end

      context "and exchange with given name DOES NOT exist" do
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
        }.to raise_error(AMQP::Channel::IncompatibleOptionsError)

        done
      end # it
    end # context
  end # describe
end # describe MQ
