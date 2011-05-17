# -*- coding: utf-8 -*-
require "spec_helper"

describe "Authentication attempt" do

  #
  # Environment
  #

  include EventedSpec::EMSpec
  include EventedSpec::SpecHelper


  describe "with default connection parameters" do

    #
    # Examples
    #

    # assuming there is an account guest with password of "guest" that has
    # access to / (default vhost)
    context "when guest/guest has access to /" do
      after :all do
        done
      end

      it "succeeds" do
        AMQP.connect do |connection|
          connection.should be_open

          connection.close { done }
        end

        done(0.5)
      end # it
    end # context
  end # describe


  describe "with explicitly given connection parameters" do

    #
    # Examples
    #

    # assuming there is an account amqp_gem with password of "amqp_gem_password" that has
    # access to /amqp_gem_testbed
    context "when amqp_gem/amqp_gem_testbed has access to amqp_gem_testbed" do
      context "and provided credentials are correct" do
        it "succeeds" do
          connection = AMQP.connect :username => "amqp_gem", :password => "amqp_gem_password", :vhost => "amqp_gem_testbed"

          done(0.5) {
            connection.should be_connected
            connection.close
          }
        end # it
      end # context

      context "and provided credentials ARE INCORRECT" do
        default_timeout 10

        after(:all) { done }

        it "fails" do
          handler = Proc.new { |settings|
            puts "Callback has fired"
            callback_has_fired = true
            done
          }
          connection = AMQP.connect(:username => "amqp_gem", :password => Time.now.to_i.to_s, :vhost => "amqp_gem_testbed", :on_possible_authentication_failure => handler)
        end # it
      end


      context "and provided vhost DOES NOT EXIST" do
        default_timeout 10

        after(:all) { done }

        it "fails" do
          handler = Proc.new { |settings|
            puts "Callback has fired"
            callback_has_fired = true
            done
          }
          connection = AMQP.connect(:username => "amqp_gem", :password => Time.now.to_i.to_s, :vhost => "/a/b/c/#{rand}/#{Time.now.to_i}", :on_possible_authentication_failure => handler)
        end # it
      end
    end # context
  end


  describe "with connection string" do

    #
    # Examples
    #

    # assuming there is an account amqp_gem with password of "amqp_gem_password" that has
    # access to /amqp_gem_testbed
    context "when amqp_gem/amqp_gem_testbed has access to amqp_gem_testbed" do
      context "and provided credentials are correct" do
        it "succeeds" do
          connection = AMQP.connect "amqp://amqp_gem:amqp_gem_password@localhost/amqp_gem_testbed"

          done(0.3) {
            connection.should be_connected
            connection.close
          }
        end # it
      end # context

      context "and provided credentials ARE INCORRECT" do
        default_timeout 10

        after(:all) { done }

        it "fails" do
          connection = AMQP.connect "amqp://amqp_gem:#{Time.now.to_i}@localhost/amqp_gem_testbed", :on_possible_authentication_failure => Proc.new { |settings|
            puts "Callback has fired"
            done
          }
        end # it
      end # context
    end # context
  end # describe
end # describe "Authentication attempt"
