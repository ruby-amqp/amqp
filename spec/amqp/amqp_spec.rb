require 'spec_helper'
require 'amqp-spec/rspec'

require 'amqp'

module MockClientModule
  def my_mock_method
  end
end

class MockClient
  include AMQP::Client
end

describe AMQP, 'as a class' do

  context 'has class accessors, with default values' do
    subject { AMQP }

    its(:logging) { should be_false }
    its(:connection) { should be_nil }
    its(:conn) { should be_nil } # Alias for #connection
    its(:closing) { should be_false }
    its(:settings) { should == {:host=>"127.0.0.1",
                                :port=>5672,
                                :user=>"guest",
                                :pass=>"guest",
                                :vhost=>"/",
                                :timeout=>nil,
                                :logging=>false,
                                :ssl=>false} }
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
  end

  describe '.connect' do
    it 'delegates to Client.connect' do
      AMQP::Client.should_receive(:connect).with("args")
      AMQP.connect "args"
    end

    it 'raises error unless called inside EM event loop' do
      expect { AMQP.connect {} }.to raise_error RuntimeError, /eventmachine not initialized/
    end

    context 'when called inside EM event loop, it either' do
      include AMQP::EMSpec

      it 'raises connection error (with wrong AMQP opts), or' do
        expect { @conn = AMQP.connect(host: 'wrong') }.
            to raise_error EventMachine::ConnectionError, /unable to resolve server address/
        done
      end
      it 'establishes connection to AMQP broker (with right AMQP options). Mind the delay!' do
        @conn = AMQP.connect AMQP_OPTS
#      p (@conn.methods - Object.methods).sort #class.ancestors.first.should == MockClientModule
        @conn.should be_kind_of AMQP::Client::EM_CONNECTION_CLASS
        @conn.should_not be_connected
        done(0.1) { @conn.should be_connected }
      end

    end
  end

  describe '.start' do
    it 'starts new EM loop and never returns from it' do
      EM.should_receive(:run).with no_args
      AMQP.start "connect_args"
    end

    it 'calls .connect inside block given to EM.run (inside EM loop, that is)' do
      EM.should_receive(:run) do |*args, &block|
        args.should be_empty
        AMQP.should_receive(:connect).with("connect_args")
        block.call
      end
      AMQP.start "connect_args"
    end

    context 'inside EM loop' do
      include AMQP::EMSpec
      after { AMQP.cleanup_state; done }

      it 'raises connection error (with wrong AMQP opts)' do
        expect { AMQP.start(host: 'wrong') }.
            to raise_error EventMachine::ConnectionError, /unable to resolve server address/
        done
      end

      it 'sets AMQP.connection property with client instance returned by .connect' do
        AMQP.connection.should be_nil
        AMQP.start AMQP_OPTS
        AMQP.connection.should be_kind_of AMQP::Client::EM_CONNECTION_CLASS
        done
      end

      it 'yields to given block AFTER connection is established' do
        AMQP.start AMQP_OPTS do
          @block_fired = true
          AMQP.connection.should be_connected
        end
        done(0.1) { @block_fired.should be_true }
      end
    end
  end

  describe '.stop' do
    it 'is noop if connection is not established' do
      expect { @res = AMQP.stop }.to_not raise_error
      @res.should be_nil
    end

    context 'with established AMQP connection' do
      include AMQP::Spec
      after { AMQP.cleanup_state; done }
      default_options AMQP_OPTS

      it 'closes existing connection' do
        AMQP.connection.should_receive(:close).with(no_args)
        AMQP.stop
        done
      end

      it 'unsets AMQP.connection property. Mind the delay!' do
        AMQP.connection.should be_connected
        AMQP.stop
        AMQP.connection.should_not be_nil
        done(0.1) { AMQP.connection.should be_nil}
      end

      it 'yields to given block AFTER connection is disconnected (BUT before AMQP.conn is cleared!)' do
        AMQP.stop do
          @block_fired = true
          AMQP.connection.should_not be_nil
          AMQP.instance_variable_get(:@closing).should be_true
        end
        done(0.1) do
          @block_fired.should be_true
        end
      end
    end
  end

  describe '.fork' do

    it 'yields to given block in EM.fork (cleaning its own process-local properties first)' do
      EM.should_receive(:fork) do |workers, &block|
        workers.should == 'workers'
        block.call
        Thread.current[:mq].should be_nil
        AMQP.connection.should be_nil
      end
      AMQP.fork( 'workers' ){|*args| p *args}

    end
  end
end