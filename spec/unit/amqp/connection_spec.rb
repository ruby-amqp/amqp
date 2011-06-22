require 'spec_helper'
require 'amqp'

describe AMQP, 'class object' do

  #
  # Environment
  #

  subject { AMQP }

  #
  # Examples
  #

  its(:settings) do
    # TODO: rewrite using key should eql value,
    # it's not very wise to check frame_max etc.
    should == {
      :host      => "127.0.0.1",
      :port      => 5672,
      :user      => "guest",
      :pass      => "guest",
      :vhost     => "/",
      :timeout   => nil,
      :logging   => false,
      :ssl       => false,
      :broker    => nil,
      :frame_max => 131072
    }
  end

  its(:client) { should == AMQP::Session }




  describe 'logging' do
    after(:all) do
      AMQP.logging = false
    end

    it 'is silent by default' do
      AMQP.logging.should be_false
    end
  end # .logging=




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
