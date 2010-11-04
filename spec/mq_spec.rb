require 'spec_helper'
require 'amqp-spec/rspec'

require 'mq'

# Mocking AMQP::Client::EM_CONNECTION_CLASS in order to
# spec MQ instance behavior without starting EM loop.
class MockConnection

  attr_accessor :callbacks, :messages, :channels

  def callback &block
    (@callbacks||=[]) << block
    block.call(self) if block
  end

  def add_channel mq
    (@channels||={})[key = (@channels.keys.max || 0) + 1] = mq
    key
  end

  def send *args
    (@messages||=[]) << args
  end
end

describe 'MQ', 'as a class' do
#  after(:all){AMQP.cleanup_state}

  subject { MQ }

  its(:logging) { should be_false }

  describe '.logging=' do
    it 'is independent from AMQP.logging' do
      #
      AMQP.logging = true
      MQ.logging.should be_false
      MQ.logging = false
      AMQP.logging.should == true

      #
      AMQP.logging = false
      MQ.logging = true
      AMQP.logging.should be_false
      MQ.logging = false
    end
  end

  describe '.default' do
    it 'creates MQ object and stashes it in Thread-local Hash' do
      MQ.should_receive(:new).with(no_args).and_return('MQ mock')
      Thread.current.should_receive(:[]).with(:mq)
      Thread.current.should_receive(:[]=).with(:mq, 'MQ mock')
      MQ.default.should == 'MQ mock'
    end
  end

  describe '.id' do
    it 'returns Thread-local uuid for mq' do
      Thread.current.should_receive(:[]).with(:mq_id)
      Thread.current.should_receive(:[]=).with(:mq_id, /.*-[0-9]{4}-[0-9]{4}/)
      MQ.id.should =~ /.*-[0-9]{4}-[0-9]{4}/
    end
  end

  describe '.error' do
    it 'is noop unless @error_callback was previously set' do
      MQ.instance_variable_get(:@error_callback).should be_nil
      MQ.error("Whatever").should be_nil
    end

    it 'is setting @error_callback if block is given' do
      MQ.error("Whatever"){|message| message.should == "Whatever"; @callback_fired = true}
      MQ.instance_variable_get(:@error_callback).should_not be_nil
      @callback_fired.should be_false
    end

    it 'is causes @error_callback to fire if it was set' do
      MQ.error("Whatever")
      @callback_fired.should be_true
    end
  end

  describe '.method_missing' do
    it 'routes all unrecognized methods to MQ.default' do
      MQ.should_receive(:new).with(no_args).and_return(mock('schmock'))
      MQ.default.should_receive(:abracadabra).with("Whatever")
      MQ.abracadabra("Whatever")
    end
  end
end

describe 'MQ', 'object, also vaguely known as "channel"' do

  context 'when initialized with a mock connection' do
    before { EM.stub(:reactor_running?).and_return(true) }
    subject { MQ.new @conn = MockConnection.new }
    # its(:connection) { should be_nil } - does not work since in relies on subject.send(:connection)

    it 'has semi-private? accessors' do
      pending '#connection is declared as both private and public accessor for some reason... Why?'
      subject.connection.should == @conn
      subject.conn.should == @conn
    end

    it 'has public accessors' do
      subject.channel.should == 1         # Essentially, channel number
      subject.consumers.should be_a Hash
      subject.consumers.should be_empty
      subject.exchanges.should be_a Hash
      subject.exchanges.should be_empty
      subject.rpcs.should be_a Hash
      subject.rpcs.should be_empty
    end

#    its(:closing) { should be_false }
#    its(:settings) { should == {:host=>"127.0.0.1",
#                                :port=>5672,
#                                :user=>"guest",
#                                :pass=>"guest",
#                                :vhost=>"/",
#                                :timeout=>nil,
#                                :logging=>false,
#                                :ssl=>false} }
#    its(:client) { should == AMQP::BasicClient }
#
  end
#  describe '.client=' do
#    after(:all) { AMQP.client = AMQP::BasicClient }
#
#    it 'is used to change default client module' do
#      AMQP.client = MockClientModule
#      AMQP.client.should == MockClientModule
#      MockClientModule.ancestors.should include AMQP
#    end
#
#    describe 'new default client module' do
#      it 'sticks around after being assigned' do
#        AMQP.client.should == MockClientModule
#      end
#
#      it 'extends any object that includes AMQP::Client' do
#        @client = MockClient.new
#        @client.should respond_to :my_mock_method
#      end
#    end
#  end
#
#  describe '.connect' do
#    it 'delegates to Client.connect' do
#      AMQP::Client.should_receive(:connect).with("args")
#      AMQP.connect "args"
#    end
#
#    it 'raises error unless called inside EM event loop' do
end