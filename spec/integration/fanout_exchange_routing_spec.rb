# encoding: utf-8

require "spec_helper"

describe AMQP::Exchange, "of type fanout" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper

  em_before { AMQP.cleanup_state }
  em_after  { AMQP.cleanup_state }

  default_options AMQP_OPTS
  default_timeout 6

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


  context "with three bound queues" do
    it "routes all messages to all bound queues" do
      @exchange = @channel.fanout("amqpgem.integration.multicast.fanout", :auto_delete => true)
      @queue1   = @channel.queue("amqpgem.integration.multicast.queue1",  :auto_delete => true)
      @queue2   = @channel.queue("amqpgem.integration.multicast.queue2",  :auto_delete => true)
      @queue3   = @channel.queue("amqpgem.integration.multicast.queue3",  :auto_delete => true)

      @queues   = [@queue1, @queue2, @queue3]

      @received_messages = {
        @queue1.name => [],
        @queue2.name => [],
        @queue3.name => []
      }

      @expected_number_of_messages = {
        @queue1.name => 10,
        @queue2.name => 10,
        @queue3.name => 10
      }


      @sent_values = Array.new

      @queue1.bind(@exchange).subscribe do |payload|
        @received_messages[@queue1.name].push(payload.to_i)
      end # subscribe

      @queue2.bind(@exchange).subscribe do |payload|
        @received_messages[@queue2.name].push(payload.to_i)
      end # subscribe

      @queue3.bind(@exchange).subscribe do |payload|
        @received_messages[@queue3.name].push(payload.to_i)
      end # subscribe

      10.times do
        dispatched_data             = rand(5_000_000)
        @sent_values.push(dispatched_data)

        @exchange.publish(dispatched_data, :mandatory => false)
      end

      # for Rubinius, it is surprisingly slow on this workload
      done(1.5) {
        [@queue1, @queue2, @queue3].each do |q|
          @received_messages[q.name].size.should == @expected_number_of_messages[q.name]

          # this one is ordering assertion
          @received_messages[q.name].should == @sent_values
        end
      }
    end # it
  end
end # describe
