# encoding: utf-8

require 'spec_helper'
require 'amqp'

describe AMQP do

  #
  # Examples
  #

  it "has default settings" do
    s = AMQP.settings.dup

    s[:host].should == "127.0.0.1"
    s[:port].should == 5672
    s[:user].should == "guest"
    s[:pass].should == "guest"
    s[:heartbeat].should == 0
    s[:auth_mechanism].should == "PLAIN"
  end


  describe '.start' do

    #
    # Environment
    #

    include EventedSpec::SpecHelper

    em_before { AMQP.cleanup_state }
    em_after  { AMQP.cleanup_state }

    #
    # Examples
    #

    it 'yields to given block AFTER connection is established' do
      em do
        AMQP.start AMQP_OPTS do
          @block_fired = true

          AMQP.connection.should be_connected
        end
        done(0.3) { @block_fired.should be_true }
      end
    end

    it 'should try to connect again in case previous conection failed' do
      em do
        timeout(20)
        error_handler = proc { EM.next_tick { AMQP.start(AMQP_OPTS) { done } } }
        # Assuming that you don't run your amqp @ port 65535
        AMQP.start(AMQP_OPTS.merge(:port => 65535, :on_tcp_connection_failure => error_handler))

      end
    end

    it 'should keep connection if there was no failure' do
      em do
        error_handler = proc {}
        @block_fired_times = 0
        AMQP.start(AMQP_OPTS) { @block_fired_times += 1 }
        delayed(0.1) { AMQP.start(AMQP_OPTS) { @block_fired_times += 1 } }
        done(0.3) { @block_fired_times.should == 1 }
      end
    end
  end # .start
end # describe AMQP
