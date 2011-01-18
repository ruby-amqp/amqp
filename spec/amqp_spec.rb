require 'spec_helper'

require 'amqp'

module MockClientModule
  def my_mock_method
  end
end

class MockClient
  include AMQP::Client
end

describe AMQP, 'class object' do
  context 'has class accessors, with default values' do
    subject { AMQP }

    its(:logging) { should be_false }
    its(:connection) { should be_nil }
    its(:conn) { should be_nil } # Alias for #connection
    its(:closing) { should be_false }
    its(:settings) { should == {:host    => "127.0.0.1",
                                :port    => 5672,
                                :user    => "guest",
                                :pass    => "guest",
                                :vhost   => "/",
                                :timeout => nil,
                                :logging => false,
                                :ssl     => false} }

    its(:client) { should == AMQP::BasicClient }
  end



  describe '.client=' do
    after(:all) { AMQP.client = AMQP::BasicClient }

    it 'is used to change default client module' do
      AMQP.client = MockClientModule
      AMQP.client.should == MockClientModule
      MockClientModule.ancestors.should include AMQP
    end

    describe 'new default client module' do
      it 'sticks around after being assigned' do
        AMQP.client.should == MockClientModule
      end

      it 'extends any object that includes AMQP::Client' do
        @client = MockClient.new
        @client.should respond_to :my_mock_method
      end
    end
  end # .client




  describe 'logging' do
    before(:all) do
      @client = Class.new { include AMQP::Client; public :log }.new
    end

    after(:all) do
      AMQP.logging = false
    end

    it 'is silent by default' do
      AMQP.logging.should be_false
    end
  end # .logging=




  describe '.start' do
    context 'inside EM loop' do
      include AMQP::SpecHelper
      em_after { AMQP.cleanup_state }

      it 'yields to given block AFTER connection is established' do
        em do
          AMQP.start AMQP_OPTS do
            @block_fired = true
            AMQP.connection.should be_connected
          end
          done(0.1) { @block_fired.should be_true }
        end
      end
    end # context 'inside EM loop'
  end # .start




  describe '.stop' do
    it 'is noop if connection is not established' do
      expect { @res = AMQP.stop }.to_not raise_error
      @res.should be_nil
    end

    context 'with established AMQP connection' do
      include AMQP::Spec
      after { AMQP.cleanup_state; done }
      default_options AMQP_OPTS

      it 'unsets AMQP.connection property. Mind the delay!' do
        AMQP.start(AMQP_OPTS)
        AMQP.connection.should be_connected

        AMQP.stop
        AMQP.connection.should_not be_nil
        done(0.1) { AMQP.connection.should be_nil }
      end

      it 'yields to given block AFTER disconnect (BUT before AMQP.conn is cleared!)' do
        AMQP.stop do
          @block_fired = true
          AMQP.connection.should_not be_nil
          AMQP.instance_variable_get(:@closing).should be_true
        end
        done(0.1) { @block_fired.should be_true }
      end
    end # context 'with established AMQP connection'
  end # .stop
end
