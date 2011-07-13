# encoding: utf-8

require 'spec_helper'

describe "Queue that was bound to default direct exchange thanks to Automatic Mode (section 2.1.2.4 in AMQP 0.9.1 spec" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 3

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.should be_open
    @channel.on_error do |ch, close|
      raise "Channel-level error!: #{close.inspect}"
    end

    @queue1    = @channel.queue("amqpgem.tests.integration.queue1", :auto_delete => true)
    @queue2    = @channel.queue("amqpgem.tests.integration.queue2", :auto_delete => true)

    # Rely on default direct exchange binding, see section 2.1.2.4 Automatic Mode in AMQP 0.9.1 spec.
    @exchange = AMQP::Exchange.default(@channel)
  end


  default_options AMQP_OPTS


  #
  # Examples
  #

  it "receives messages with routing key equals it's name" do
    @exchange.channel.should == @channel

    number_of_received_messages = 0
    expected_number_of_messages = 3
    dispatched_data             = "to be received by queue1"

    @queue1.subscribe do |payload|
      number_of_received_messages += 1
      payload.should == dispatched_data
    end # subscribe

    4.times do
      @exchange.publish("some white noise", :routing_key => "killa key")
    end

    expected_number_of_messages.times do
      @exchange.publish(dispatched_data,    :routing_key => @queue1.name)
    end

    4.times do
      @exchange.publish("some white noise", :routing_key => "killa key")
    end

    delayed(0.6) {
      # We never subscribe to it, hence, need to delete manually
      @queue2.delete
    }

    done(0.9) {
      number_of_received_messages.should == expected_number_of_messages
    }
  end # it
end # describe
