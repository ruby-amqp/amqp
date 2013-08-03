# encoding: utf-8

require 'spec_helper'

require "amqp/settings"

describe AMQP::Settings do

  #
  # Examples
  #


  describe ".parse_connection_uri(connection_string)" do
    context "when schema is not one of [amqp, amqps]" do
      it "raises ArgumentError" do
        expect {
          described_class.parse_connection_uri("http://dev.rabbitmq.com")
        }.to raise_error(ArgumentError, /amqp or amqps schema/)
      end
    end


    it "handles amqp:// URIs w/o path part" do
      val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com")

      val[:vhost].should be_nil # in this case, default / will be used
      val[:host].should == "dev.rabbitmq.com"
      val[:port].should == 5672
      val[:scheme].should == "amqp"
      val[:ssl].should be_false
    end

    it "handles amqps:// URIs w/o path part" do
      val = described_class.parse_connection_uri("amqps://dev.rabbitmq.com")

      val[:vhost].should be_nil
      val[:host].should == "dev.rabbitmq.com"
      val[:port].should == 5671
      val[:scheme].should == "amqps"
      val[:ssl].should be_true
    end


    context "when URI ends in a slash" do
      it "parses vhost as an empty string" do
        val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com/")

        val[:host].should == "dev.rabbitmq.com"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:vhost].should == ""
      end
    end


    context "when URI ends in /%2Fvault" do
      it "parses vhost as /vault" do
        val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com/%2Fvault")

        val[:host].should == "dev.rabbitmq.com"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:vhost].should == "/vault"
      end
    end


    context "when URI is amqp://dev.rabbitmq.com/a.path.without.slashes" do
      it "parses vhost as a.path.without.slashes" do
        val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com/a.path.without.slashes")

        val[:host].should == "dev.rabbitmq.com"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:vhost].should == "a.path.without.slashes"
      end
    end

    context "when URI is amqp://dev.rabbitmq.com/a/path/with/slashes" do
      it "raises an ArgumentError" do
        lambda { described_class.parse_connection_uri("amqp://dev.rabbitmq.com/a/path/with/slashes") }.should raise_error(ArgumentError)
      end
    end


    context "when URI has username:password, for instance, amqp://hedgehog:t0ps3kr3t@hub.megacorp.internal" do
      it "parses them out" do
        val = described_class.parse_connection_uri("amqp://hedgehog:t0ps3kr3t@hub.megacorp.internal")

        val[:host].should == "hub.megacorp.internal"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:user].should == "hedgehog"
        val[:pass].should == "t0ps3kr3t"
        val[:vhost].should be_nil # in this case, default / will be used
      end
    end
  end
end
