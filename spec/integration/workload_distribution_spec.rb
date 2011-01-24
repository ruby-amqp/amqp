# -*- coding: utf-8 -*-
require "spec_helper"

describe "Workload distribution" do

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
    amqp_before :each do
      @exchange = @channel.fanout("amqpgem.integration.multicast.fanout", :auto_delete => true)
    end

    context "with three bound queues" do
      amqp_before :each do
        @queue1   = @channel.queue("amqpgem.integration.multicast.queue1",  :auto_delete => true)
        @queue2   = @channel.queue("amqpgem.integration.multicast.queue2",  :auto_delete => true)
        @queue3   = @channel.queue("amqpgem.integration.multicast.queue3",  :auto_delete => true)

        @queues   = [@queue1, @queue2, @queue3]

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
      end

      amqp_before :each do
        @received_messages = {
          @queue1.name => [],
          @queue2.name => [],
          @queue3.name => []
        }

        @expected_number_of_messages = {
          @queue1.name => 100,
          @queue2.name => 100,
          @queue3.name => 100
        }
      end

      amqp_after :each do
        @sent_values.clear
      end


      context "and messages are published as non-mandatory" do
        it "routes all messages to all bound queues" do
          100.times do
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
      end # context



      context "and messages are published as mandatory" do
        it "routes all messages to all bound queues" do
          100.times do
            dispatched_data             = rand(5_000_000)
            @sent_values.push(dispatched_data)

            @exchange.publish(dispatched_data, :mandatory => true)
          end

          # 6 seconds are for Rubinius, it is surprisingly slow on this workload
          done(1.5) {
            [@queue1, @queue2, @queue3].each do |q|
              @received_messages[q.name].size.should == @expected_number_of_messages[q.name]

              # this one is ordering assertion
              @received_messages[q.name].should == @sent_values
            end
          }
        end # it
      end # context



      context "and messages are published as non-persistent" do
        it "routes all messages to all bound queues" do
          100.times do
            dispatched_data             = rand(5_000_000)
            @sent_values.push(dispatched_data)

            @exchange.publish(dispatched_data, :persistent => false)
          end

          # 6 seconds are for Rubinius, it is surprisingly slow on this workload
          done(1.5) {
            [@queue1, @queue2, @queue3].each do |q|
              @received_messages[q.name].size.should == @expected_number_of_messages[q.name]

              # this one is ordering assertion
              @received_messages[q.name].should == @sent_values
            end
          }
        end # it
      end # context



      context "and messages are published as persistent" do
        it "routes all messages to all bound queues" do
          100.times do
            dispatched_data             = rand(5_000_000)
            @sent_values.push(dispatched_data)

            @exchange.publish(dispatched_data, :persistent => true)
          end

          # 6 seconds are for Rubinius, it is surprisingly slow on this workload
          done(1.5) {
            [@queue1, @queue2, @queue3].each do |q|
              @received_messages[q.name].size.should == @expected_number_of_messages[q.name]

              # this one is ordering assertion
              @received_messages[q.name].should == @sent_values
            end
          }
        end # it
      end # context


      context "and messages are published as non-immediate" do
        it "routes all messages to all bound queues" do
          100.times do
            dispatched_data             = rand(5_000_000)
            @sent_values.push(dispatched_data)

            @exchange.publish(dispatched_data, :immediate => false)
          end

          # 6 seconds are for Rubinius, it is surprisingly slow on this workload
          done(1.5) {
            [@queue1, @queue2, @queue3].each do |q|
              @received_messages[q.name].size.should == @expected_number_of_messages[q.name]

              # this one is ordering assertion
              @received_messages[q.name].should == @sent_values
            end
          }
        end # it
      end # context



      context "and messages are published as immediate" do
        it "may get a Basic.Return back"
      end # context



      context "and messages are published WITHOUT routing key" do
        it "routes all messages to all bound queues" do
          100.times do
            dispatched_data             = rand(5_000_000)
            @sent_values.push(dispatched_data)

            @exchange.publish(dispatched_data)
          end

          # 6 seconds are for Rubinius, it is surprisingly slow on this workload
          done(1.5) {
            [@queue1, @queue2, @queue3].each do |q|
              @received_messages[q.name].size.should == @expected_number_of_messages[q.name]

              # this one is ordering assertion
              @received_messages[q.name].should == @sent_values
            end
          }
        end # it
      end # context


      context "and messages are published WITH routing key that matches name of one of the queues" do
        it "routes all messages to all bound queues" do
          100.times do
            dispatched_data             = rand(5_000_000)
            @sent_values.push(dispatched_data)

            @exchange.publish(dispatched_data, :routing_key => @queues.sample.name)
          end

          # 6 seconds are for Rubinius, it is surprisingly slow on this workload
          done(1.5) {
            [@queue1, @queue2, @queue3].each do |q|
              @received_messages[q.name].size.should == @expected_number_of_messages[q.name]

              # this one is ordering assertion
              @received_messages[q.name].should == @sent_values
            end
          }
        end # it
      end # context
    end # context
  end # context
end # describe
