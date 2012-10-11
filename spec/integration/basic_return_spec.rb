# encoding: utf-8

require "spec_helper"


describe "Message published as mandatory" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper

  em_before { AMQP.cleanup_state }
  em_after  { AMQP.cleanup_state }

  default_options AMQP_OPTS
  default_timeout 3

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.should be_open

    @exchange = @channel.fanout("amqpgem.specs.#{Time.now.to_i}", :auto_delete => true, :durable => false)
  end

  after(:all) do
    AMQP.cleanup_state
    done
  end


  context "that cannot be routed to any queue" do
    it "is returned to the publisher via basic.return" do
      returned_messages  = []

      @exchange.on_return do |basic_return, header, body|
        returned_messages << basic_return.reply_text
      end
      (1..10).to_a.each { |m| @exchange.publish(m, :mandatory => true) }

      done(1.0) {
        returned_messages.should == Array.new(10) { "NO_ROUTE" }
      }
    end
  end
end
