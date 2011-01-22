# -*- coding: utf-8 -*-
require "spec_helper"

describe "Store-and-forward routing" do

  #
  # Environment
  #

  include AMQP::Spec
  include AMQP::SpecHelper

  em_before { AMQP.cleanup_state }
  em_after  { AMQP.cleanup_state }

  default_options AMQP_OPTS
  default_timeout 5

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
      it "routes all messages to the same queue" do
        exchange = @channel.fanout("amqpgem.integration.snf.fanout", :auto_delete => true)
        queue    = @channel.queue("amqpgem.integration.snf.queue1",  :auto_delete => true)

        number_of_received_messages = 0
        # put a little pressure
        expected_number_of_messages = 3000
        # It is always a good idea to use non-ASCII charachters in
        # various test suites. MK.
        dispatched_data             = "libertà è participazione (inviato a #{Time.now.to_i})"


        queue.bind(exchange).subscribe do |payload|
          number_of_received_messages += 1
          payload.force_encoding("UTF-8").should == dispatched_data
        end # subscribe

        expected_number_of_messages.times do
          exchange.publish(dispatched_data)
        end

        done(3.0) {
          number_of_received_messages.should == expected_number_of_messages
        }
      end # it
    end # context
  end # context
end # describe
