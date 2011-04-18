# -*- coding: utf-8 -*-
require "spec_helper"

describe "Authentication attempt" do

  #
  # Environment
  #

  include AMQP::Spec
  include AMQP::SpecHelper

  em_before { AMQP.cleanup_state }
  em_after  { AMQP.cleanup_state }


  # Tests below use AMQP_OPTS for settings, if you really need to modify them,
  # create amqp.yml file with new settings. (see spec/spec_helper)

  # Also it assumes that guest/guest has access to /
  describe "with default connection parameters" do
    #
    # Examples
    #


    context "when guest/guest has access to /" do
      after :all do
        done
      end

      it "succeeds" do
        connection = AMQP.connect

        done(0.3) {
          connection.should be_connected
          connection.close
        }
      end # it
    end # context
  end # describe


  describe "with explicitly given connection parameters" do

    #
    # Examples
    #

    # assuming AMQP_OPTS are correct
    # and SchadenFreude with random password doesn't have any access
    context "when #{AMQP_OPTS[:username]} has access to #{AMQP_OPTS[:vhost]}" do
      after :all do
        done
      end

      context "and provided credentials are correct" do
        it "succeeds" do
          connection = AMQP.connect :username => AMQP_OPTS[:username], :password => AMQP_OPTS[:password], :vhost => AMQP_OPTS[:vhost]

          done(0.3) {
            connection.should be_connected
            connection.close
          }
        end # it
      end # context

      context "and provided credentials ARE INCORRECT" do
        it "fails" do
          connection = AMQP.connect :user => "SchadenFreude", :pass => Time.now.to_i.to_s, :vhost => AMQP_OPTS[:vhost]

          done(0.5) {
            connection.should_not be_connected
          }
        end # it
      end
    end # context
  end


  describe "with connection string" do

    #
    # Examples
    #

    # assuming AMQP_OPTS are correct
    # and SchadenFreude with random password doesn't have any access
    context "when #{AMQP_OPTS[:username]} has access to #{AMQP_OPTS[:vhost]}" do
      after :all do
        done
      end

      context "and provided credentials are correct" do
        it "succeeds" do
          connection = AMQP.connect "amqp://#{AMQP_OPTS[:username]}:#{AMQP_OPTS[:password]}@localhost#{AMQP_OPTS[:vhost]}"

          done(0.3) {
            connection.should be_connected
            connection.close
          }
        end # it
      end # context

      context "and provided credentials ARE INCORRECT" do
        it "succeeds" do
          connection = AMQP.connect "amqp://schadenfreude:#{Time.now.to_i}@localhost/"

          done(0.5) {
            connection.should_not be_connected
            connection.close
          }
        end # it
      end # context
    end # context
  end # describe
end # describe "Authentication attempt"
