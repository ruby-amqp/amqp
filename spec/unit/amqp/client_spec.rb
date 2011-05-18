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


    it "handles amqp:// URIs w/o path part"

    it "handles amqps:// URIs w/o path part"
  end
end
