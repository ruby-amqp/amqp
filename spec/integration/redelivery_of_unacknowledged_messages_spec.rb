# encoding: utf-8

require 'spec_helper'

describe "Unacknowledged messages" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 5

  amqp_before do
    @connection1 = AMQP.connect
    @connection2 = AMQP.connect
    @connection3 = AMQP.connect

    @channel1    = AMQP::Channel.new(@connection1)
    @channel2    = AMQP::Channel.new(@connection2)
    @channel3    = AMQP::Channel.new(@connection3)

    [@channel1, @channel2, @channel3].each { |ch| ch.on_error { fail } }

    @channel1.prefetch(3)
    @channel2.prefetch(1)
  end

  after(:all) do
    AMQP.cleanup_state
    done
  end



  #
  # Examples
  #

  # this is a spec example based on one of the Working With Queues doc guides.
  # It is somewhat hairy since it imitates 3 apps in a single process
  # but demonstrates redeliveries pretty well. MK.

  it "are redelivered to alternate consumers when the 'primary' one disconnects" do
    number_of_messages_app2_received = 0
    expected_number_of_deliveries    = 21
    redelivery_values                = Array.new

    exchange = @channel3.direct("amq.direct")

    queue1    = @channel1.queue("amqpgem.examples.acknowledgements.explicit", :auto_delete => false)
    # purge the queue so that we don't get any redeliveries from previous runs
    queue1.purge
    queue1.bind(exchange).subscribe(:ack => true) do |metadata, payload|
      # acknowledge some messages, they will be removed from the queue
      if metadata.headers["i"] < 10
        @channel1.acknowledge(metadata.delivery_tag, false)
      else
        # some messages are not ack-ed and will remain in the queue for redelivery
        # when app #1 connection is closed (either properly or due to a crash)
      end
    end

    queue2    = @channel2.queue!("amqpgem.examples.acknowledgements.explicit", :auto_delete => false)
    queue2.subscribe(:ack => true) do |metadata, payload|
      redelivery_values << metadata.redelivered?

      # app 2 always acks messages
      metadata.ack

      number_of_messages_app2_received += 1
    end

    EventMachine.add_timer(2.0) {
      # app1 quits/crashes
      @connection1.close
    }


    # 0.5 seconds later, publish a bunch of messages
    EventMachine.add_timer(0.5) {
      30.times do |i|
        exchange.publish("Message ##{i}", :headers => { :i => i })
        i += 1
      end
    }


    done(4.8) {
      number_of_messages_app2_received.should be >= expected_number_of_deliveries
      # 3 last messages are redeliveries
      redelivery_values.last(7).should == [false, false, false, false, true, true, true]
    }
  end
end
