require 'spec_helper'
require 'mq_helper'

describe MQ::Queue, 'with mock connection and channel' do
  before do
    # Mocking connected client and connected mq (channel) that uses it
    @client = MockConnection.new
    @mq = MQ.new(@client).tap { |mq| mq.succeed }
  end

  after { AMQP.cleanup_state }

  context '#new' do

    it 'creates new Queue with empty bindings' do
      @queue = MQ::Queue.new(@mq, 'test_queue')
      @queue.name.should == 'test_queue'
      @queue.instance_variable_get(:@bindings).should be_empty
    end

    it 'creates new Queue with options' do
      @queue = MQ::Queue.new(@mq, 'test_queue', :option => 'useless')
      @queue.name.should == 'test_queue'
      @queue.instance_variable_get(:@bindings).should be_empty
      @queue.instance_variable_get(:@opts).should == {:option => 'useless'}
    end

    it 'adds created Queue to channel`s queues set' do
      @mq.queues.should_receive(:[]=) do |key, queue|
        key.should == 'test_queue'
        queue.should be_a MQ::Queue
        queue.name.should == 'test_queue'
      end
      @queue = MQ::Queue.new(@mq, 'test_queue')
    end

    it 'sends AMQP Queue::Declare method through channel' do
      @mq.should_receive(:send) do |method|
        method.should be_an AMQP::Protocol::Queue::Declare
        method.queue.should == 'test_queue'
        method.nowait.should == true
      end
      @queue = MQ::Queue.new(@mq, 'test_queue')
    end

    it 'can set Declare options such as :ticket, :passive, :durable, ' +
           ':exclusive, :auto_delete, :nowait and :arguments' do
      @mq.should_receive(:send) do |method|
        method.should be_an AMQP::Protocol::Queue::Declare
        method.queue.should == 'test_queue'
        method.ticket.should == 1313
        method.nowait.should be_false
        method.passive.should == true
        method.durable.should == true
        method.exclusive.should == true
        method.auto_delete.should == true
        method.arguments.should == ['blah']
      end
      @queue = MQ::Queue.new(@mq, 'test_queue', :ticket => 1313, :passive => true,
                             :durable => true, :exclusive => true, :auto_delete => true,
                             :nowait => false, :arguments => ['blah'])
    end
  end #new

  context 'with declared Queue "test_queue"' do
    before { @queue = MQ::Queue.new(@mq, 'test_queue', :option => 'useless') }
    subject { @queue }

    describe '#bind', 'binds queue to an exchange' do

      it 'creates new exchange binding for this queue, saving binding options' do
        @queue.instance_variable_get(:@bindings).should be_empty
        @queue.bind('test_exchange', :ticket => 1313, :key => 'key',
                    :nowait => false, :arguments => ['blah'])
        @queue.instance_variable_get(:@bindings)['test_exchange'].should ==
            {:ticket => 1313, :key => 'key', :nowait => false, :arguments => ['blah']}
      end

      it 'accepts both exchange name and MQ::Exchange object' do
        @queue.instance_variable_get(:@bindings).should be_empty
        @queue.bind(@mq.direct('test_exchange'))
        @queue.instance_variable_get(:@bindings)['test_exchange'].should_not be_nil
      end

      it 'sends AMQP Queue::Bind method through channel' do
        @mq.should_receive(:send) do |method|
          method.should be_an AMQP::Protocol::Queue::Bind
          method.queue.should == 'test_queue'
          method.exchange.should == 'test_exchange'
          method.nowait.should == true
          method.routing_key.should == nil
        end
        @queue.bind('test_exchange')
      end

      it 'can set options such as :ticket, :key, :nowait and :arguments' do
        @mq.should_receive(:send) do |method|
          method.should be_an AMQP::Protocol::Queue::Bind
          method.queue.should == 'test_queue'
          method.exchange.should == 'test_exchange'
          method.nowait.should be_false
          method.ticket.should == 1313
          method.routing_key.should == 'key'
          method.arguments.should == ['blah']
        end
        @queue.bind('test_exchange', :ticket => 1313,
                    :key => 'key', :nowait => false, :arguments => ['blah'])
      end

      it 'returns self for method chains' do
        @queue.bind('test_exchange').should == @queue
      end
    end #bind

    describe '#unbind', 'removes binding between queue and exchange' do
      before { @queue.bind('test_exchange') }

      context 'when binding to exchange exists' do
        it 'removes binding of this queue to given exchange' do
          @queue.bind('test_exchange')
          @queue.instance_variable_get(:@bindings)['test_exchange'].should_not be_nil
          @queue.unbind('test_exchange')
          @queue.instance_variable_get(:@bindings)['test_exchange'].should == nil
        end

        it 'accepts both exchange name and MQ::Exchange object' do
          @queue.unbind(@mq.direct('test_exchange'))
          @queue.instance_variable_get(:@bindings)['test_exchange'].should == nil
        end

        it 'sends AMQP Queue::Unbind method through channel' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Queue::Unbind
            method.queue.should == 'test_queue'
            method.exchange.should == 'test_exchange'
          end
          @queue.unbind('test_exchange')
        end

        it 'can set options such as :ticket, :key, :nowait and :arguments' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Queue::Unbind
            method.queue.should == 'test_queue'
            method.exchange.should == 'test_exchange'
            method.ticket.should == 1313
            method.routing_key.should == 'key'
            method.arguments.should == ['blah']
#            method.nowait.should == true
          end
          @queue.unbind('test_exchange', :ticket => 1313, :key => 'key',
                        :arguments => ['blah'])
        end

        it 'returns self for method chains' do
          @queue.unbind('test_exchange').should == @queue
        end
      end # when binding to exchange exists

      it 'does not raise anything if unbinding non-existing binding/exchange' do
        @queue.unbind('test_exchange')
        @queue.instance_variable_get(:@bindings)['test_exchange'].should == nil
      end

      it 'but probably channel exception will be raised for non-existing binding/exchange?'
      it 'seems like setting :nowait in Protocol::Queue::Unbind is unnecessary'
    end #unbind

    describe '#delete', 'deletes this Queue, cancelling all consumers' do

      it 'deletes this queue from channel`s queue set' do
        @queue.delete
        @mq.queues[@queue.name].should == nil
      end

      it 'sends AMQP Queue::Delete method through channel' do
        @mq.should_receive(:send) do |method|
          method.should be_an AMQP::Protocol::Queue::Delete
          method.queue.should == 'test_queue'
          method.nowait.should == true
        end
        @queue.delete
      end

      it 'can set option :nowait' do
        @mq.should_receive(:send) do |method|
          method.should be_an AMQP::Protocol::Queue::Delete
          method.queue.should == 'test_queue'
          method.nowait.should be_false
        end
        @queue.delete(:nowait => false)
      end

      it 'always returns nil' do
        @queue.delete.should == nil
      end
    end #delete

    describe '#purge', 'requests broker to purge/clear this Queue' do

      it 'sends AMQP Queue::Purge method through channel' do
        @mq.should_receive(:send) do |method|
          method.should be_an AMQP::Protocol::Queue::Purge
          method.queue.should == 'test_queue'
          method.nowait.should == true
        end
        @queue.purge
      end

      it 'can set option :nowait' do
        @mq.should_receive(:send) do |method|
          method.should be_an AMQP::Protocol::Queue::Purge
          method.queue.should == 'test_queue'
          method.nowait.should be_false
        end
        @queue.purge(:nowait => false)
      end

      it 'always returns nil' do
        @queue.purge.should == nil
      end
    end #purge

    describe '#pop', 'provides a direct synchronous access to the messages in a queue' do

      it 'pushes self into channel`s get_queue FIFO' do
        @queue.pop
        @mq.get_queue { |fifo| fifo.should == [@queue] }
      end

      it 'sends AMQP Basic::Get method through channel' do
        @mq.should_receive(:send) do |method|
          method.should be_an AMQP::Protocol::Basic::Get
          method.queue.should == 'test_queue'
        end
        @queue.pop
      end

      it 'can set options such as :ticket, :no_ack' do
        @mq.should_receive(:send) do |method|
          method.should be_an AMQP::Protocol::Basic::Get
          method.queue.should == 'test_queue'
          method.ticket.should == 1313
          method.no_ack.should == true
        end
        @queue.pop(:ticket => 1313, :no_ack => true)
      end

      it 'accepts both exchange name and MQ::Exchange object' do
        @queue.unbind(@mq.direct('test_exchange'))
        @queue.instance_variable_get(:@bindings)['test_exchange'].should == nil
      end

      it 'returns self for method chains' do
        @queue.pop.should == @queue
      end

      it 'seems like :consumer_tag and :nowait in Protocol::Basic::Get are unnecessary'
    end #pop

    context 'managing asynchronous subscription to queue messages' do

      describe '#subscribe', 'subscribes to asynchronous message delivery' do
        it 'adds self to channel`s subscribers set (with random-generated consumer tag' do
          @queue.subscribe
          tag = @mq.consumers.keys.last
          @mq.consumers[tag].should == @queue
        end

        it 'sends Basic::Consume through channel' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Basic::Consume
            method.queue.should == 'test_queue'
            method.consumer_tag.should =~ /test_queue-\d*/
            method.no_ack.should == true
            method.nowait.should == true
          end
          @queue.subscribe
        end

        it 'can set options such as :ticket, :no_local, :exclusive, :no_ack, :nowait' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Basic::Consume
            method.queue.should == 'test_queue'
            method.consumer_tag.should =~ /test_queue-\d*/
            method.ticket.should == 1313
            method.no_ack.should be_false
            method.nowait.should be_false
            method.no_local.should == true
            method.exclusive.should == true
          end
          @queue.subscribe( :ticket => 1313, :no_ack => false, :no_local => true,
                            :exclusive => true, :nowait => false)
        end

        it 'option :confirm sets @on_confirm_subscribe hook, to be called later' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Basic::Consume
            method.nowait.should be_false
          end
          @queue.subscribe(:confirm => 'hook')
          @queue.instance_variable_get(:@on_confirm_subscribe).should == 'hook'
        end

        it 'returns self for method chains' do
          @queue.subscribe.should == @queue
        end

        it 'raises error if #subscribe is called twice for the Queue' do
          @queue.subscribe {}
          expect { @queue.subscribe }.to raise_error /already subscribed to the queue/
        end
      end #subscribe

      describe '#confirm_subscribe', 'called by @mq(channel) when subscription confirmed' do
        it 'calls @on_confirm_subscribe hook(if any), then unsets it' do
          subject_mock(:@on_confirm_subscribe).should_receive(:call).with(no_args)
          @queue.confirm_subscribe
          @queue.instance_variable_get(:@on_confirm_subscribe).should == nil
        end
      end #confirm_subscribe

      describe '#unsubscribe', 'cancels the subscription' do
        before { @queue.subscribe {} }

        it 'does not remove self from channel`s subscribers set just yet' do
          tag = @mq.consumers.keys.last
          @queue.unsubscribe
          @mq.consumers[tag].should == @queue
        end

        it 'sends Basic::Consume through channel' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Basic::Cancel
            method.consumer_tag.should =~ /test_queue-\d*/
            method.nowait.should be_false
          end
          @queue.unsubscribe
        end

        it 'can set :nowait option' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Basic::Cancel
            method.consumer_tag.should =~ /test_queue-\d*/
            method.nowait.should == true
          end
          @queue.unsubscribe(:nowait => true)
        end

        it 'returns self for method chains' do
          @queue.unsubscribe.should == @queue
        end

      end #unsubscribe

      describe '#cancelled', 'called by @mq(channel) when broker confirmed cancellation' do
        before { @queue.subscribe {} }

        it 'calls @on_cancel hook(if any), then unsets it' do
          subject_mock(:@on_cancel).should_receive(:call).with(no_args)
          @queue.cancelled
          @queue.instance_variable_get(:@on_cancel).should == nil
        end

        it 'unsets @on_msg hook' do
          subject_mock(:@on_msg)
          @queue.cancelled
          @queue.instance_variable_get(:@on_msg).should == nil
        end

        it 'removes this queue from channel`s consumers set' do
          tag = @mq.consumers.keys.last
          @mq.consumers[tag].should == @queue
          @queue.cancelled
          @mq.consumers[tag].should == nil
        end

        it 'does not remove this queuefrom @mq.queues set' do
          @mq.queues.should_not_receive(:delete)
          @queue.cancelled
        end

        it 'removes it from @mq.queues if it was declared with :auto_delete option' do
          # Since it will be auto-deleted by broker once subscription cancelled
          queue = MQ::Queue.new(@mq, 'another_test_queue', :auto_delete => true)
          @mq.queues.should_receive(:delete).with(queue.name)
          queue.cancelled
        end
      end #cancelled

      describe '#subscribed?' do
        it 'tests whether this queue is already subscribed' do
          @queue.should_not be_subscribed
          @queue.subscribe {}
          @queue.should be_subscribed
          @queue.cancelled
          @queue.should_not be_subscribed
        end
      end #subscribed?
    end # managing async subscription

    describe '#publish', 'publishing "directly" to @queue' do
      it 'implicitly creates direct noname Exchange with :key=> @queue.name' do
        MQ::Exchange.should_receive(:new).with(@mq, :direct, '', hash_including(:key)).
            and_return(exchange = mock('exchange'))
        exchange.should_receive(:publish).with('data', hash_including(:option))
        @queue.publish 'data', :option => 'useless'
      end
    end #publish

    describe '#receive' do
      it 'calls @on_msg(if any) with received message body' do
        on_msg = subject_mock(:@on_msg)
        on_msg.should_receive(:arity).and_return(1)
        on_msg.should_receive(:call).with(:body)
        @queue.receive :header, :body
      end

      it 'calls @on_msg with (casted) header and body, if @on_msg arity is 2' do
        on_msg = subject_mock(:@on_msg)
        on_msg.should_receive(:arity).and_return(2)
        on_msg.should_receive(:call) do |header, body|
          header.should be_an MQ::Header
          header.to_sym.should == :header
          body.should == :body
        end
        @queue.receive :header, :body
      end

      it 'does not cast nil header into MQ::Header' do
        on_msg = subject_mock(:@on_msg)
        on_msg.should_receive(:arity).and_return(2)
        on_msg.should_receive(:call) do |header, body|
          header.should == nil
          body.should == :body
        end
        @queue.receive nil, :body
      end

      it 'calls @on_pop if @on_msg is nil' do
        @queue.instance_variable_get(:@on_msg).should be_nil
        on_pop = subject_mock(:@on_pop)
        on_pop.should_receive(:arity).and_return(1)
        on_pop.should_receive(:call).with(:body)
        @queue.receive :header, :body
      end

      it 'calls @on_pop with (casted) header and body, if @on_pop arity is 2' do
        subject.instance_variable_get(:@on_msg).should be_nil
        on_pop = subject_mock(:@on_pop)
        on_pop.should_receive(:arity).and_return(2)
        on_pop.should_receive(:call) do |header, body|
          header.should be_an MQ::Header
          header.to_sym.should == :header
          body.should == :body
        end
        @queue.receive :header, :body
      end

      it 'does not call @on_pop if @on_msg exists' do
        on_pop = subject_mock(:@on_pop)
        on_msg = subject_mock(:@on_msg).as_null_object
        on_pop.should_not_receive(:arity)
        on_pop.should_not_receive(:call)
        @queue.receive :header, :body
      end
    end #receive

    context 'retrieving queue status' do
      describe '#status' do
        it 'sets @on_status hook to be called back with Queue::DeclareOk result' do
          @queue.instance_variable_get(:@on_status).should be_nil
          @queue.status {}
          @queue.instance_variable_get(:@on_status).should be_a Proc
        end

        it 're-sends AMQP Queue::Declare method (with :passive option)' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Queue::Declare
            method.queue.should == 'test_queue'
            method.nowait.should be_false
            method.passive.should == true
          end
          @queue.status
        end

        it 'can set typical Declare options such as :ticket, :passive, :durable, ' +
               ':exclusive, :auto_delete, :nowait and :arguments' do
          @mq.should_receive(:send) do |method|
            method.should be_an AMQP::Protocol::Queue::Declare
            method.queue.should == 'test_queue'
            method.ticket.should == 1313
            method.nowait.should == true
            method.durable.should == true
            method.exclusive.should == true
            method.auto_delete.should == true
            method.arguments.should == ['blah']
          end
          @queue.status(:ticket => 1313, :durable => true, :exclusive => true,
                        :auto_delete => true, :nowait => true, :arguments => ['blah'])
        end
      end #status

      describe '#receive_status' do
        let(:declare_ok) { AMQP::Protocol::Queue::DeclareOk.new(:queue => @queue.name,
                                                                :message_count => 20,
                                                                :consumer_count => 1) }

        it 'calls @on_status hook with data extracted from received Queue::DeclareOk' do
          on_status = subject_mock(:@on_status)
          on_status.should_receive(:arity).and_return(2)
          on_status.should_receive(:call).with(
              declare_ok.message_count, declare_ok.consumer_count)
          @queue.receive_status(declare_ok)
        end

        it 'gives @on_status hook only message_count if its arity is 1' do
          on_status = subject_mock(:@on_status)
          on_status.should_receive(:arity).and_return(1)
          on_status.should_receive(:call).with(declare_ok.message_count)
          @queue.receive_status(declare_ok)
        end

        it 'then unsets @on_status hook' do
          subject_mock(:@on_status).as_null_object
          @queue.receive_status(declare_ok)
          @queue.instance_variable_get(:@on_status).should == nil
        end

      end #receive_status
    end #retrieving queue status

    describe '#reset' do

      it 'at minimum, reinitializes the queue' do
        @queue.should_receive(:initialize).with(@mq, @queue.name, @queue.instance_variable_get(:@opts))
        @queue.should_not_receive(:bind)
        @queue.should_not_receive(:subscribe)
        @queue.should_not_receive(:pop)
        @queue.reset
      end

      it 're-binds, re-subscribes and re-pops as necessary' do
        @queue.bind('exch')
        @queue.subscribe {}
        @queue.pop {}
        @queue.should_receive(:initialize).with(@mq, @queue.name, @queue.instance_variable_get(:@opts))
        @queue.should_receive(:bind).with('exch', {})
        @queue.should_receive(:subscribe)
        @queue.should_receive(:pop)
        @queue.reset
      end
    end #reset
  end # with declared Queue "test_queue"
end # with mock connection

describe MQ::Queue, 'with real AMQP connection', :broker => true do
  include AMQP::Spec
  default_options AMQP_OPTS
  default_timeout 2

  amqp_before do
    @mq = MQ.new
    @queue = MQ::Queue.new(@mq, 'test_queue', :option => 'useless')
  end

  amqp_after { @queue.purge; AMQP.cleanup_state }

  context 'with declared Queue "test_queue"' do
    amqp_after {@queue.unsubscribe; @queue.delete}
    # TODO: Fix amqp_after: it is NOT run in case of raised exceptions, it seems

    it 'works for basic pub/sub scenario (implicitly uses default amq.direct exchange)' do
      @queue.subscribe do |header, message|
        header.should be_an MQ::Header
        message.should == 'data'
        done
      end
      @queue.publish('data')
    end

    it 'works for basic pop (Basic::Get) scenario' do
      @queue.publish('data')
      @queue.pop do |header, message|
        header.should be_an MQ::Header
        message.should == 'data'
        done
      end
    end

    it 'should retrieve queue status when requested' do
      @queue.publish('data1')
      @queue.publish('data2')
      @queue.status do |messages, consumers|
        @on_status_fired = true
        messages.should == 2
        consumers.should == 0
      end
      done(1)
    end

    context 'effect of Queue declaration options (:passive, :durable, etc)'
    context 'effect of edge cases (unbinding when no binding created, etc)'

    describe '#pop', 'provides a direct synchronous access to the messages in a queue' do
      it 'calls back given block upon Basic::GetOk or BasicGetEmpty from broker'
    end

    describe '#subscribe', 'subscribes to asynchronous message delivery' do
      it 'calls back Queue#confirm_subscribe when broker confirms subscription'
      it 'calls given block whenever message is delivered from broker'
    end

    describe '#unsubscribe', 'cancels the subscription' do
      it 'calls back Queue#cancelled when broker confirms subscription cancellation'
    end

  end # with declared Queue "test_queue"
end # MQ::Queue, 'with real connection
