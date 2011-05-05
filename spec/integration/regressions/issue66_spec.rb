# -*- coding: utf-8 -*-
require "spec_helper"

describe "Authentication attempt" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
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
        c = AMQP.connect
        c.disconnect

        done
      end # it
    end # context
  end # describe
end # describe "Authentication attempt"
