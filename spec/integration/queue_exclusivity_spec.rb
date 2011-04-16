# encoding: utf-8

require 'spec_helper'

describe "Non-exclusive queue" do

  #
  # Environment
  #

  include EventedSpec::EMSpec

  default_timeout 5

  em_after { @connection1.close; @connection2.close }
  #
  # Examples
  #

  it "can be used across multiple connections" do
    @connection1 = AMQP.connect do
      @connection2 = AMQP.connect do
        @connection1.should_not == @connection2

        channel1 = AMQP::Channel.new(@connection1)
        channel2 = AMQP::Channel.new(@connection2)

        instance1 = AMQP::Queue.new(channel1, "amqpgem.integration.queues.non-exclusive", :exclusive => false, :auto_delete => true)
        instance2 = AMQP::Queue.new(channel2, "amqpgem.integration.queues.non-exclusive", :exclusive => false, :auto_delete => true)

        exchange1 = channel1.fanout("amqpgem.integration.exchanges.fanout1", :auto_delete => true)
        exchange2 = channel2.fanout("amqpgem.integration.exchanges.fanout2", :auto_delete => true)


        instance1.bind(exchange1).subscribe do |payload|
        end

        instance2.bind(exchange2).subscribe do |payload|
        end

        done(0.2) {
          channel1.should be_open
          channel1.close

          channel2.should be_open
          channel2.close
        }
      end
    end
  end
end



describe "Exclusive queue" do

  #
  # Environment
  #

  include EventedSpec::EMSpec

  default_timeout 2

  em_after { @connection1.close; @connection2.close }


  #
  # Examples
  #

  it "can ONLY be used by ONE connection" do
    @connection1 = AMQP.connect do
      @connection2 = AMQP.connect do
        @connection1.should_not == @connection2

        queue_name = "amqpgem.integration.queues.exclusive"
        callback_fired = false
        @channel1 = AMQP::Channel.new(@connection1) do
          AMQP::Queue.new(@channel1, queue_name, :exclusive => true) do
            @channel2 = AMQP::Channel.new(@connection2) do
              AMQP::Queue.new(@channel2, queue_name, :exclusive => true) do
                callback_fired = true
              end
            end
          end
        end

        done(1) {
          callback_fired.should be_false
          @channel1.should_not be_closed
          # because it is a channel-level exception
          @channel2.should be_closed
        }
      end
    end
  end
end
