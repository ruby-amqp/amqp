# encoding: utf-8

require "spec_helper"

describe "Store-and-forward routing" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper

  em_before { AMQP.cleanup_state }
  em_after  { AMQP.cleanup_state }

  default_options AMQP_OPTS
  default_timeout 10

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.should be_open
  end

  after(:all) do
    AMQP.cleanup_state
    done
  end


  #
  # Examples
  #

  context "that uses fanout exchange" do
    context "with a single bound queue" do
      amqp_before do
        @queue_name = "amqpgem.integration.snf.queue1"

        @exchange = @channel.direct("")
        @queue    = @channel.queue(@queue_name, :auto_delete => true, :nowait => false)
      end

      it "allows asynchronous subscription to messages WITHOUT acknowledgements" do
        number_of_received_messages = 0
        # put a little pressure
        expected_number_of_messages = 300
        # It is always a good idea to use non-ASCII charachters in
        # various test suites. MK.
        dispatched_data             = "messages sent at #{Time.now.to_i}"

        @queue.purge
        @queue.subscribe(:ack => false) do |payload|
          payload.should be_instance_of(String)
          number_of_received_messages += 1
          payload.should == dispatched_data
        end # subscribe

        delayed(0.3) do
          expected_number_of_messages.times do
            @exchange.publish(dispatched_data, :routing_key => @queue_name)
          end
        end

        done(4.0) {
          number_of_received_messages.should == expected_number_of_messages
          @queue.unsubscribe
        }
      end # it


      it "allows asynchronous subscription to messages WITH acknowledgements" do
        number_of_received_messages = 0
        expected_number_of_messages = 500

        @queue.subscribe(:ack => true) do |payload|
          number_of_received_messages += 1
        end # subscribe

        expected_number_of_messages.times do
          @exchange.publish(rand, :key => @queue_name)
        end

        # 5 seconds are for Rubinius, it is surprisingly slow on this workload
        done(5.0) {
          number_of_received_messages.should == expected_number_of_messages
          @queue.unsubscribe
        }
      end # it
    end
  end # context
end # describe
