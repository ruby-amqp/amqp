# encoding: utf-8

require 'spec_helper'

describe "Server-named", AMQP::Queue do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 5

  amqp_before do
    @channel = AMQP::Channel.new
  end


  #
  # Examples
  #


  it "can be declared en masse" do
    n       = 100
    queues  = []

    n.times do
      queues << @channel.queue("", :auto_delete => true)
    end

    done(0.5) {
      queues.size.should == n
      queues.all? { |q| q.name =~ /^amq.*/ }.should be_true
    }
  end
end
