# encoding: utf-8
require 'spec_helper'


describe "AMQP transaction rollback" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_timeout 4.5

  amqp_before do
    @producer_channel    = AMQP::Channel.new
    @consumer_channel    = AMQP::Channel.new
  end

  # ...


  #
  # Examples
  #

  it "voids messages published since the last tx.select" do
    exchange = @producer_channel.fanout("amq.fanout")
    queue    = @consumer_channel.queue("", :exclusive => true)

    queue.bind(exchange).subscribe do |metadata, payload|
      fail "Consumer received a message before transaction committed"
    end

    @producer_channel.tx_select
    EventMachine.add_timer(0.5) do
      50.times { exchange.publish("before tx.commit") }
      @producer_channel.tx_rollback
    end

    done(3.5)
  end # it
end # describe




describe "AMQP connection closure that follows tx.select" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_timeout 4.5

  amqp_before do
    @producer_channel    = AMQP::Channel.new
    @consumer_channel    = AMQP::Channel.new
  end

  # ...


  #
  # Examples
  #

  it "voids messages published since the last tx.select" do
    exchange = @producer_channel.fanout("amq.fanout")
    queue    = @consumer_channel.queue("", :exclusive => true)

    queue.bind(exchange).subscribe do |metadata, payload|
      fail "Consumer received a message before transaction committed"
    end

    @producer_channel.tx_select
    EventMachine.add_timer(0.5) do
      3.times { exchange.publish("before tx.commit") }
      @producer_channel.connection.close
    end

    done(3.5)
  end # it
end # describe




describe "AMQP channel closure that follows tx.select" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_timeout 4.5

  amqp_before do
    @producer_channel    = AMQP::Channel.new
    @consumer_channel    = AMQP::Channel.new
  end

  # ...


  #
  # Examples
  #

  it "voids messages published since the last tx.select" do
    exchange = @producer_channel.fanout("amq.fanout")
    queue    = @consumer_channel.queue("", :exclusive => true)

    queue.bind(exchange).subscribe do |metadata, payload|
      fail "Consumer received a message before transaction committed"
    end

    @producer_channel.tx_select
    EventMachine.add_timer(0.5) do
      3.times { exchange.publish("before tx.commit") }
      @producer_channel.close
    end

    done(3.5)
  end # it
end # describe



describe "AMQP transaction rollback attempt on a non-transactional channel" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  default_timeout 4.5

  amqp_before do
    @producer_channel    = AMQP::Channel.new
    @consumer_channel    = AMQP::Channel.new
  end

  # ...


  #
  # Examples
  #

  it "causes channel-level exception" do
    exchange = @producer_channel.fanout("amq.fanout")
    queue    = @consumer_channel.queue("", :exclusive => true)

    queue.bind(exchange).subscribe do |metadata, payload|
      fail "Consumer received a message before transaction committed"
    end

    @producer_channel.on_error do |ch, channel_close|
      puts "#{channel_close.reply_text}"
      done
    end
    EventMachine.add_timer(0.5) { @producer_channel.tx_rollback }

    done(3.5)
  end # it
end # describe
