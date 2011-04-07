# -*- coding: utf-8 -*-
require "spec_helper"

describe AMQP::Queue, "#pop" do

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

    @queue_name = "amqpgem.integration.basic.get.queue"

    @exchange = @channel.direct("")
    @queue    = @channel.queue(@queue_name, :auto_delete => true, :nowait => false)
  end

  after(:all) do
    AMQP.cleanup_state
    done
  end


  #
  # Examples
  #

  context "when there are messages in the queue" do
    amqp_before { @queue.purge :nowait => true }
    it "yields nil (instead of message payload) to the callback" do
      callback_has_fired = false

      @queue.status do |number_of_messages, number_of_consumers|
        number_of_messages.should == 0
      end

      @queue.pop do |payload|
        callback_has_fired = true

        payload.should be_nil
      end

      done(0.2) {
        callback_has_fired.should be_true
      }
    end
  end

  context "when there are messages in the queue" do  
    it "yields message payload to the callback" do
      number_of_received_messages = 0
      expected_number_of_messages = 300

      dispatched_data             = "fetch me synchronously"

      @queue.purge :nowait => true
      expected_number_of_messages.times do |i|
        @exchange.publish(dispatched_data + "_#{i}", :key => @queue_name)
      end

      @queue.status do |number_of_messages, number_of_consumers|
        number_of_messages.should == expected_number_of_messages

        expected_number_of_messages.times do
          @queue.pop do |payload|
            payload.should_not be_nil
            number_of_received_messages += 1

            if RUBY_VERSION =~ /^1.9/
              payload.force_encoding("UTF-8").should == dispatched_data
            else
              payload.should == dispatched_data
            end
          end # pop
        end # do
      end

      done(1.5) {
        number_of_received_messages.should == expected_number_of_messages
      }
    end # it
  end # context
end # describe
