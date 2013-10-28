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

  after(:all) do
    AMQP.cleanup_state
    done
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
      context "and :nowait isn't used" do
        it "uses server-assigned queue name" do
          @channel.queue("") do |queue, *args|
            queue.name.should_not be_empty
            queue.should be_anonymous
            queue.delete
            done
          end
        end
      end


      context "and :nowait is used" do
        it "raises ArgumentError" do
          expect { AMQP::Queue.new(@channel, "", :nowait => true) }.to raise_error(ArgumentError, /makes no sense/)
          expect { @channel.queue("", :nowait => true) }.to raise_error(ArgumentError, /makes no sense/)

          done
        end
      end # context
    end

    context "when queue name is nil" do
      it "raises ArgumentError" do
        expect { AMQP::Queue.new(@channel, nil) }.to raise_error(ArgumentError, /queue name must not be nil/)
        expect { @channel.queue(nil) }.to raise_error(ArgumentError, /queue name must not be nil/)

        done
      end
    end # context


    context "when queue is redeclared with different attributes" do
      let(:name)              { "amqp-gem.nondurable.queue" }
      let(:options)           {
        { :durable => false, :passive => false }
      }
      let(:different_options) {
        { :durable => true, :passive => false}
      }
      amqp_before do
        @queue       = @channel.queue(name, options)
        delayed(0.25) { @queue.delete }
      end

      context "on the same channel" do
        it "should raise ruby exception" do
          expect {
            @channel.queue(name, different_options)
          }.to raise_error(AMQP::IncompatibleOptionsError)
          @queue.delete
          done
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
