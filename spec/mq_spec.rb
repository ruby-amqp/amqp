require 'spec_helper'
require 'amqp-spec/rspec'

require 'mq'

# Mocking AMQP::Client::EM_CONNECTION_CLASS in order to
# specify MQ instance behavior without the need to start EM loop.
class MockConnection

  def initialize
    EM.should_receive(:reactor_running?).and_return(true)
  end

  def callback &block
    callbacks << block
    block.call(self) if block
  end

  def add_channel mq
    channels[key = (channels.keys.max || 0) + 1] = mq
    key
  end

  def send data, opts = {}
    messages << {data: data, opts: opts}
  end

  def connected?
    true
  end

  def channels
    @channels||={}
  end

  # Not part of AMQP::Client::EM_CONNECTION_CLASS interface, for mock introspection only
  def callbacks
    @callbacks||=[]
  end

  def messages
    @messages||=[]
  end
end

describe 'MQ', 'as a class' do
#  after{AMQP.cleanup_state} # Tips off Thread.current[:mq] call
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
      Thread.current.should_receive(:[]=).with(:mq_id, /.*-[0-9]{4,5}-[0-9]{10}/)
      MQ.id.should =~ /.*-[0-9]{4,5}-[0-9]{10}/
    end
  end

  describe '.error' do
    it 'is noop unless @error_callback was previously set' do
      MQ.instance_variable_get(:@error_callback).should be_nil
      MQ.error("Whatever").should be_nil
    end

    it 'is setting @error_callback if block is given' do
      MQ.error("Whatever") { |message| message.should == "Whatever"; @callback_fired = true }
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
    before { @conn = MockConnection.new }
    after { AMQP.cleanup_state }
    subject { MQ.new(@conn).tap { |mq| mq.succeed } } # Indicates that channel is connected
    # its(:connection) { should be_nil } - does not work since in relies on subject.send(:connection)

    it 'has public accessors' do
      subject.channel.should == 1 # Essentially, channel number
      subject.consumers.should be_a Hash
      subject.consumers.should be_empty
      subject.exchanges.should be_a Hash
      subject.exchanges.should be_empty
      subject.queues.should be_a Hash
      subject.queues.should be_empty
      subject.rpcs.should be_a Hash
      subject.rpcs.should be_empty

      # '#connection was declared as both private and public accessor for some reason... Why?'
      subject.connection.should == @conn
      subject.conn.should == @conn
    end

    describe '#process_frame' # The meat of mq operations

  # Sends each argument through @connection, setting its *ticket* property to the @ticket
  # received in most recent Protocol::Access::RequestOk. This operation is Mutex-synchronized.
  #
#  def send *args
#    conn.callback { |c|
#      (@_send_mutex ||= Mutex.new).synchronize do
#        args.each do |data|
#          data.ticket = @ticket if @ticket and data.respond_to? :ticket=
#          log :sending, data
#          c.send data, :channel => @channel
#        end
#      end
#    }
#  end


    describe '#send' do

    it 'sends given data through its connection' do
      args = [mock('data1'), mock('data2'), mock('data3')]

      subject.send *args

      @conn.messages[-3..-1].map{|message| message[:data]}.should == args
    end

    it 'sets data`s ticket property if @ticket is set for MQ object' do
      subject.instance_variable_set(:@ticket, ticket = 'mock ticket')
      data = mock('data1')
      data.should_receive(:ticket=).with(ticket)

      subject.send data
    end

    it 'is Mutex-synchronized' do
      mutex = subject.instance_variable_get(:@_send_mutex)
      mutex.should_receive(:synchronize)
      subject.send mock('data1')
    end
  end


    describe '#reset' do
      it 'resets and reinitializes the channel, clears and resets its queues/exchanges' do
        subject.queue('test').should_receive(:reset)
        subject.fanout('fanout').should_receive(:reset)
        subject.should_receive(:initialize).with(@conn)

        subject.reset
        subject.queues.should be_empty
        subject.exchanges.should be_empty
        subject.consumers.should be_empty
      end
    end

    describe '#prefetch' do
      it 'sends Protocol::Basic::Qos, setting :prefetch_count for broker' do
        subject.prefetch 13
        @conn.messages.last[:data].should be_an AMQP::Protocol::Basic::Qos
        @conn.messages.last[:data].instance_variable_get(:@prefetch_count).should == 13
      end

      it 'returns MQ object itself, allowing for method chains' do
        subject.prefetch(1).should == subject
      end
    end

    describe '#recover' do
      it 'sends Protocol::Basic::Recover, asking broker to redeliver all unack`ed messages on this channel' do
        subject.recover
        @conn.messages.last[:data].should be_an AMQP::Protocol::Basic::Recover
      end

      it 'by default, requeue property is nil, so messages will be redelivered to the original recipient' do
        subject.recover
        @conn.messages.last[:data].instance_variable_get(:@requeue).should == nil
      end

      it 'you can set requeue to true, prompting broker to requeue the messages (to other subscribers, potentially)' do
        subject.recover true
        @conn.messages.last[:data].instance_variable_get(:@requeue).should == true
      end

      it 'returns MQ object itself, allowing for method chains' do
        subject.recover.should == subject
      end
    end

    describe '#close' do
      it 'can be simplified, getting rid of @closing ivar? Just set callback sending Protocol::Channel::Close...'

      it 'sends Protocol::Channel::Close through @connection' do
        subject.close
        @conn.messages.last[:data].should be_an AMQP::Protocol::Channel::Close
      end

      it 'does not actually delete the channel or close connection' do
        @conn.channels.should_not_receive(:delete)
        @conn.should_not_receive(:close)
        subject.close
      end

      it 'actual closing of the channel happens ONLY when Protocol::Channel::CloseOk is received' do
        @conn.channels.should_receive(:delete) {|key| key.should == 1; @conn.channels.clear }
        @conn.should_receive(:close)
        subject.process_frame AMQP::Frame::Method.new( AMQP::Protocol::Channel::CloseOk.new)
      end
    end

    describe '#get_queue' do
      it 'yields a FIFO queue to a given block' do
        subject.get_queue do |fifo|
          fifo.should == []
        end
      end

      it 'FIFO queue contains consumers that called Queue#pop' do
        queue = subject.queue('test')
        queue.pop
        queue.pop
        subject.get_queue do |fifo|
          fifo.should have(2).consumers
          fifo.each { |consumer| consumer.should == queue }
        end
      end

      it 'is Mutex-synchronized' do
        subject # Evaluates subject, tripping add_channel Mutex at initialize
        mutex = Mutex.new
        Mutex.should_receive(:new).and_return(mutex)
        mutex.should_receive(:synchronize)
        subject.get_queue {}
      end
    end

    describe '#connected?' do # This is an addition to standard MQ interface
      it 'delegates to @connection to determine its connectivity status' do
        @conn.should_receive(:connected?).with(no_args)
        subject.connected?
      end
    end

    describe 'setting up exchanges/queues/rpcs' do
      describe '#rpc' do
        it 'creates new rpc and saves it into @rpcs Hash' do
          MQ::RPC.should_receive(:new).with(subject, 'name', nil).and_return('mock_rpc')
          subject.rpcs.should_receive(:[]=).with('name', 'mock_rpc')
          rpc = subject.rpc 'name'
          rpc.should == 'mock_rpc'
        end

        it 'raises error rpc if no name given' do
          expect { subject.rpc }.to raise_error ArgumentError
        end

        it 'does not replace rpc with existing name' do
          MQ::RPC.should_receive(:new).with(subject, 'name', nil).and_return('mock_rpc')
          subject.rpc 'name'
          MQ::RPC.should_not_receive(:new)
          subject.rpcs.should_not_receive(:[]=)
          rpc = subject.rpc 'name'
          rpc.should == 'mock_rpc'
        end
      end

      describe '#queue' do
        it 'creates new Queue and saves it into @queues Hash' do
          MQ::Queue.should_receive(:new).with(subject, 'name', {}).and_return('mock_queue')
          subject.queues.should_receive(:[]=).with('name', 'mock_queue')
          queue = subject.queue 'name'
          queue.should == 'mock_queue'
        end

        it 'raises error Queue if no name given' do
          expect { subject.queue }.to raise_error ArgumentError
        end

        it 'does not replace queue with existing name' do
          MQ::Queue.should_receive(:new).with(subject, 'name', {}).and_return('mock_queue')
          subject.queue 'name'
          MQ::Queue.should_not_receive(:new)
          subject.queues.should_not_receive(:[]=)
          queue = subject.queue 'name'
          queue.should == 'mock_queue'
        end
      end

      describe '#direct' do
        it 'creates new :direct Exchange and saves it into @exchanges Hash' do
          MQ::Exchange.should_receive(:new).with(subject, :direct, 'name', {}).and_return('mock_exchange')
          subject.exchanges.should_receive(:[]=).with('name', 'mock_exchange')
          exchange = subject.direct 'name'
          exchange.should == 'mock_exchange'
        end

        it 'creates "amq.direct" Exchange if no name given' do
          MQ::Exchange.should_receive(:new).with(subject, :direct, 'amq.direct', {}).and_return('mock_exchange')
          subject.exchanges.should_receive(:[]=).with('amq.direct', 'mock_exchange')
          exchange = subject.direct
          exchange.should == 'mock_exchange'
        end

        it 'does not replace exchange with existing name' do
          MQ::Exchange.should_receive(:new).with(subject, :direct, 'name', {}).and_return('mock_exchange')
          subject.direct 'name'
          MQ::Exchange.should_not_receive(:new)
          subject.exchanges.should_not_receive(:[]=)
          exchange = subject.direct 'name'
          exchange.should == 'mock_exchange'
        end
      end

      describe '#fanout' do
        it 'creates new :fanout Exchange and saves it into @exchanges Hash' do
          MQ::Exchange.should_receive(:new).with(subject, :fanout, 'name', {}).and_return('mock_exchange')
          subject.exchanges.should_receive(:[]=).with('name', 'mock_exchange')
          exchange = subject.fanout 'name'
          exchange.should == 'mock_exchange'
        end

        it 'creates "amq.fanout" Exchange if no name given' do
          MQ::Exchange.should_receive(:new).with(subject, :fanout, 'amq.fanout', {}).and_return('mock_exchange')
          subject.exchanges.should_receive(:[]=).with('amq.fanout', 'mock_exchange')
          exchange = subject.fanout
          exchange.should == 'mock_exchange'
        end

        it 'does not replace exchange with existing name' do
          MQ::Exchange.should_receive(:new).with(subject, :fanout, 'name', {}).and_return('mock_exchange')
          subject.fanout 'name'
          MQ::Exchange.should_not_receive(:new)
          subject.exchanges.should_not_receive(:[]=)
          exchange = subject.fanout 'name'
          exchange.should == 'mock_exchange'
        end
      end

      describe '#topic' do
        it 'creates new :topic Exchange and saves it into @exchanges Hash' do
          MQ::Exchange.should_receive(:new).with(subject, :topic, 'name', {}).and_return('mock_exchange')
          subject.exchanges.should_receive(:[]=).with('name', 'mock_exchange')
          exchange = subject.topic 'name'
          exchange.should == 'mock_exchange'
        end

        it 'creates "amq.topic" Exchange if no name given' do
          MQ::Exchange.should_receive(:new).with(subject, :topic, 'amq.topic', {}).and_return('mock_exchange')
          subject.exchanges.should_receive(:[]=).with('amq.topic', 'mock_exchange')
          exchange = subject.topic
          exchange.should == 'mock_exchange'
        end

        it 'does not replace exchange with existing name' do
          MQ::Exchange.should_receive(:new).with(subject, :topic, 'name', {}).and_return('mock_exchange')
          subject.topic 'name'
          MQ::Exchange.should_not_receive(:new)
          subject.exchanges.should_not_receive(:[]=)
          exchange = subject.topic 'name'
          exchange.should == 'mock_exchange'
        end
      end

      describe '#headers' do
        it 'creates new :headers Exchange and saves it into @exchanges Hash' do
          MQ::Exchange.should_receive(:new).with(subject, :headers, 'name', {}).and_return('mock_exchange')
          subject.exchanges.should_receive(:[]=).with('name', 'mock_exchange')
          exchange = subject.headers 'name'
          exchange.should == 'mock_exchange'
        end

        it 'creates "amq.match" Exchange if no name given' do
          MQ::Exchange.should_receive(:new).with(subject, :headers, 'amq.match', {}).and_return('mock_exchange')
          subject.exchanges.should_receive(:[]=).with('amq.match', 'mock_exchange')
          exchange = subject.headers
          exchange.should == 'mock_exchange'
        end

        it 'does not replace exchange with existing name' do
          MQ::Exchange.should_receive(:new).with(subject, :headers, 'name', {}).and_return('mock_exchange')
          subject.headers 'name'
          MQ::Exchange.should_not_receive(:new)
          subject.exchanges.should_not_receive(:[]=)
          exchange = subject.headers 'name'
          exchange.should == 'mock_exchange'
        end
      end
    end
  end
end