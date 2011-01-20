require "spec_helper"

describe "Authentication attempt" do

  #
  # Environment
  #

  include AMQP::Spec
  include AMQP::SpecHelper

  em_before { AMQP.cleanup_state }
  em_after  { AMQP.cleanup_state }

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

    # assuming there is an account amqp_gem with password of "amqp_gem_password" that has
    # access to /amqp_gem_testbed
    context "when amqp_gem/amqp_gem_testbed has access to /amqp_gem_testbed" do
      after :all do
        done
      end

      context "and provided credentials are correct" do
        it "succeeds" do
          connection = AMQP.connect :username => "amqp_gem", :password => "amqp_gem_password", :vhost => "/amqp_gem_testbed"

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


  describe "with connection string" do

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
          connection = AMQP.connect "amqp://amqp_gem:amqp_gem_password@localhost/amqp_gem_testbed"

          done(0.3) {
            connection.should be_connected
            connection.close
          }
        end # it
      end # context

      context "and provided credentials ARE INCORRECT" do
        it "succeeds" do
          connection = AMQP.connect "amqp://amqp_gem:#{Time.now.to_i}@localhost/amqp_gem_testbed"

          done(0.5) {
            connection.should_not be_connected
            connection.close
          }
        end # it
      end # context
    end # context
  end # describe
end # describe "Authentication attempt"
