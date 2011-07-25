# encoding: utf-8

require "spec_helper"

# this example group ensures no message size is special
# (with respect to framing edge cases). MK.
describe "Stress test with messages with incrementing sizes" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_options AMQP_OPTS
  default_timeout 60

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.on_error do |ch, close|
      raise "Channel-level error!: #{close.inspect}"
    end

    @queue    = @channel.queue("", :auto_delete => true)
    @exchange = @channel.fanout("amqpgem.tests.integration.fanout.exchange", :auto_delete => true)

    @queue.bind(@exchange)
  end


  #
  # Examples
  #

  it "passes" do
    list     = Range.new(0, 4785).to_a
    received = Array.new

    @queue.subscribe do |metadata, payload|
      received << payload.bytesize

      done if received == list
    end

    EventMachine.add_timer(1.0) do
      list.each do |n|
        @exchange.publish("i" * n)
      end      
    end
  end
end