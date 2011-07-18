# encoding: utf-8

require 'spec_helper'

describe "Message attributes" do

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

  it "can be accessed in a unified manner (basic.delivery attributes + message attributes)" do
    queue    = @channel.queue("amqpgem.tests.metadata_access", :auto_delete => true)
    exchange = @channel.direct("amq.direct")

    queue.bind(exchange, :routing_key => "amqpgem.key")

    @channel.on_error do |ch, channel_close|
      fail(channel_close.reply_text)
      @connection.close { EventMachine.stop }
    end

    @now     = Time.now
    @payload = "Hello, world!"

    queue.subscribe do |metadata, payload|
      metadata.routing_key.should  == "amqpgem.key"
      metadata.content_type.should == "application/octet-stream"
      metadata.priority.should     == 8

      time = metadata.headers["time"]
      time.year.should == @now.year
      time.month.should == @now.month
      time.day.should == @now.day
      time.hour.should == @now.hour
      time.min.should == @now.min
      time.sec.should == @now.sec

      metadata.headers["coordinates"]["latitude"].should    == 59.35
      metadata.headers["participants"].should == 11
      metadata.headers["venue"].should == "Stockholm"
      metadata.headers["true_field"].should == true
      metadata.headers["false_field"].should == false
      metadata.headers["nil_field"].should be_nil
      metadata.headers["ary_field"].should == ["one", 2.0, 3, [{ "abc" => 123 }]]

      metadata.timestamp.should == Time.at(@now.to_i)
      metadata.type.should == "kinda.checkin"
      metadata.consumer_tag.should_not be_nil
      metadata.consumer_tag.should_not be_empty
      metadata.delivery_tag.should == 1
      metadata.reply_to.should == "a.sender"
      metadata.correlation_id.should == "r-1"
      metadata.message_id.should == "m-1"
      metadata.should_not be_redelivered

      metadata.app_id.should == "amqpgem.example"
      metadata.exchange.should == "amq.direct"
      payload.should == @payload

      done
    end

    exchange.publish(@payload,
                     :app_id      => "amqpgem.example",
                     :priority    => 8,
                     :type        => "kinda.checkin",
                     # headers table keys can be anything
                     :headers     => {
                       :coordinates => {
                         :latitude  => 59.35,
                         :longitude => 18.066667
                       },
                       :time         => @now,
                       :participants => 11,
                       :venue        => "Stockholm",
                       :true_field   => true,
                       :false_field  => false,
                       :nil_field    => nil,
                       :ary_field    => ["one", 2.0, 3, [{ "abc" => 123 }]]
                     },
                     :timestamp      => @now.to_i,
                     :reply_to       => "a.sender",
                     :correlation_id => "r-1",
                     :message_id     => "m-1",
                     :routing_key    => "amqpgem.key")
  end
end
