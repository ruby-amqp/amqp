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

  its(:client) { should == AMQP::BasicClient }




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
        done(0.1) { @block_fired.should be_true }
      end
    end
  end # .start




  describe '.stop' do
    context "when connection is not established" do
      it 'is a no-op' do
        AMQP.stop
        AMQP.stop

        @res = AMQP.stop
        @res.should be_nil
      end # it
    end # context


    context 'with established AMQP connection' do

      #
      #
      #

      include EventedSpec::AMQPSpec
      after           { AMQP.cleanup_state; done }
      default_options AMQP_OPTS

      #
      # Examples
      #

      it 'properly closes AMQP broker connection and fires a callback. Mind the delay!' do
        AMQP.start(AMQP_OPTS)
        AMQP.connection.should be_connected

        @block_has_fired = false

        AMQP.stop do
          @block_has_fired = true
        end
        AMQP.connection.should_not be_nil
        done(0.1) do
          @block_has_fired.should be_true
        end
      end # it
    end # context
  end # describe
end # describe AMQP
