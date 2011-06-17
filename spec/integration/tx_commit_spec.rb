# encoding: utf-8
require 'spec_helper'


describe "Messages published before AMQP transaction commits" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_timeout 1.5

  amqp_before do
    @producer_channel    = AMQP::Channel.new
    @consumer_channel    = AMQP::Channel.new
  end

  # ...


  #
  # Examples
  #

  it "are not accessible to AMQP consumers" do
    exchange = @producer_channel.fanout("amq.fanout")
    queue    = @consumer_channel.queue("", :exclusive => true)

    queue.bind(exchange).subscribe do |metadata, payload|
      fail "Consumer received a message before transaction committed"
    end

    @producer_channel.tx_select
    EventMachine.add_timer(0.5) do
      50.times { exchange.publish("before tx.commit") }
      # @producer_channel.tx_commit
    end

    done(1.2)
  end # it
end # describe




describe "AMQP transaction commit" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_timeout 1.5

  amqp_before do
    @producer_channel    = AMQP::Channel.new
    @consumer_channel    = AMQP::Channel.new
  end

  # ...


  #
  # Examples
  #

  it "causes messages published since the last tx.select to be delivered to AMQP consumers" do
    exchange = @producer_channel.fanout("amq.fanout")
    queue    = @consumer_channel.queue("", :exclusive => true)

    queue.bind(exchange).subscribe { |metadata, payload| done }

    @producer_channel.tx_select
    EventMachine.add_timer(0.5) do
      50.times { exchange.publish("before tx.commit") }
      @producer_channel.tx_commit
    end

    done(1.2)
  end # it
end # describe
