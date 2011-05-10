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
        done(0.1) { @block_fired.should be_true }
      end
    end
  end # .start
end # describe AMQP
