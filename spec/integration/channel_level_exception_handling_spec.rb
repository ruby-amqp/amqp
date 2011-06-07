# encoding: utf-8

require 'spec_helper'

describe "Channel-level exception" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 2

  amqp_before do
    @connection = AMQP.connect
    @channel    = AMQP::Channel.new(@connection)
  end

  after(:all) do
    AMQP.cleanup_state
    done
  end


  #
  # Examples
  #

  it "can be handled with Channel#on_error" do
    @channel.on_error do |ch, channel_close|
      channel_close.method_id.should == 10
      channel_close.class_id.should == 50
      channel_close.reply_code.should == 406
      channel_close.reply_text.should_not be_nil
      channel_close.reply_text.should_not be_empty

      done
    end

    EventMachine.add_timer(0.4) do
      # these two definitions result in a race condition. For sake of this example,
      # however, it does not matter. Whatever definition succeeds first, 2nd one will
      # cause a channel-level exception (because attributes are not identical)
      #
      # 'a' * 80 makes queue name long enough for complete error message to be longer than 127 charachters.
      # makes it possible to detect signed vs unsigned integer issues in amq-protocol. MK.
      AMQP::Queue.new(@channel, "amqpgem.examples.channel_exception.#{'a' * 80}", :auto_delete => true, :durable => false)

      AMQP::Queue.new(@channel, "amqpgem.examples.channel_exception.#{'a' * 80}", :auto_delete => true, :durable => true)
    end
  end
end
