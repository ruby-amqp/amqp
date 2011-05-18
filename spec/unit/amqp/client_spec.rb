# encoding: utf-8

require 'spec_helper'

describe AMQP::Client do

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

      val[:vhost].should be_nil
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


    context "when URI ends in two consecutive slashes (//)" do
      it "parses vhost as /" do
        val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com//")

        val[:host].should == "dev.rabbitmq.com"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:vhost].should == "/"
      end
    end


    context "when URI ends in //vault" do
      it "parses vhost as /vault" do
        val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com//vault")

        val[:host].should == "dev.rabbitmq.com"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:vhost].should == "/vault"
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


    context "when URI is amqp://dev.rabbitmq.com/i.am.a.vhost.without.slashes" do
      it "parses vhost as i.am.a.vhost.without.slashes" do
        val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com/i.am.a.vhost.without.slashes")

        val[:host].should == "dev.rabbitmq.com"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:vhost].should == "i.am.a.vhost.without.slashes"
      end
    end


    context "when URI is amqp://dev.rabbitmq.com/production" do
      it "parses vhost as production" do
        val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com/production")

        val[:host].should == "dev.rabbitmq.com"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:vhost].should == "production"
      end
    end


    context "when URI is amqp://dev.rabbitmq.com///a/b/c/d" do
      it "parses vhost as ///a/b/c/d" do
        val = described_class.parse_connection_uri("amqp://dev.rabbitmq.com///a/b/c/d")

        val[:host].should == "dev.rabbitmq.com"
        val[:port].should == 5672
        val[:scheme].should == "amqp"
        val[:ssl].should be_false
        val[:vhost].should == "//a/b/c/d"
      end
    end
  end
end
