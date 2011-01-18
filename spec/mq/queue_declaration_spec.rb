# encoding: utf-8

require 'spec_helper'

describe MQ do

  #
  # Environment
  #

  include AMQP::Spec

  default_timeout 5

  amqp_before do
    @channel = MQ.new
  end


  #
  # Examples
  #

  describe "#queue" do
    context "when queue name is specified" do
    end # context

    context "when queue name is omitted" do
    end # context
  end # describe
end # describe MQ
