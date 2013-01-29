# encoding: utf-8

require 'spec_helper'

describe "An individual binding" do

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
  end


  default_options AMQP_OPTS


  it "can be deleted by specifying routing key" do
    flag1 = false
    flag2 = false

    x  = @channel.direct("amqpgem.examples.imaging")

    q = @channel.queue("", :exclusive => true)
    q.bind(x, :routing_key => "resize").bind(x, :routing_key => "watermark").subscribe do |meta, payload|
      flag1 = (meta.routing_key == "watermark")
      flag2 = (meta.routing_key == "resize")
    end

    EventMachine.add_timer(0.5) do
      q.unbind(x, :routing_key => "resize") do
        x.publish("some data", :routing_key => "resize")
        x.publish("some data", :routing_key => "watermark")
      end

      done(1.0) {
        flag1.should be_true
        flag2.should be_false
      }
    end
  end
end
