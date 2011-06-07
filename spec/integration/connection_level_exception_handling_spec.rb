# encoding: utf-8

require 'spec_helper'

describe "Connection-level exception" do

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

  it "can be handled with Session#on_error" do
    @connection.on_error do |conn, connection_close|
      conn.should == @connection

      connection_close.method_id.should == 31
      connection_close.class_id.should == 10
      connection_close.reply_code.should == 504
      connection_close.reply_text.should_not be_nil
      connection_close.reply_text.should_not be_empty

      done
    end

    EventMachine.add_timer(0.3) do
      # send_frame is NOT part of the public API, but it is public for entities like AMQ::Client::Channel
      # and we use it here to trigger a connection-level exception. MK.
      @connection.send_frame(AMQ::Protocol::Connection::TuneOk.encode(1000, 1024 * 128 * 1024, 10))
    end
  end
end
