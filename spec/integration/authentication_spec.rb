require "spec_helper"

describe "Authentication attempt with default connection parameters" do

  #
  # Environment
  #

  include AMQP::Spec
  include AMQP::SpecHelper

  em_before { AMQP.cleanup_state }
  em_after  { AMQP.cleanup_state }


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
      connection = AMQP.connect

      done(0.3) {
        connection.should be_connected
        connection.close
      }
    end # it
  end # context
end # describe


describe "Authentication attempt with explicitly given connection parameters" do

  #
  # Environment
  #

  include AMQP::Spec


  #
  # Examples
  #

  # assuming there is an account amqp_gem with password of "amqp_gem_password" that has
  # access to /amqp_gem_testbed
  context "when amqp_gem/amqp_gem_testbed has access to /amqp_gem_testbed" do
    after :all do
      done
    end

    context "and provided credentials are correct" do
      it "succeeds" do
        connection = AMQP.connect :user => "amqp_gem", :pass => "amqp_gem_password", :vhost => "/amqp_gem_testbed"

        done(0.3) {
          connection.should be_connected
          connection.close
        }
      end # it
    end # context

    context "and provided credentials ARE INCORRECT" do
      it "succeeds" do
        connection = AMQP.connect :user => "amqp_gem", :pass => Time.now.to_i.to_s, :vhost => "/amqp_gem_testbed"

        done(0.5) {
          connection.should_not be_connected
        }
      end # it
    end

  end # context
end


describe "Authentication attempt with connection string" do
end

