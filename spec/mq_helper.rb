# This helper supports writing specs for MQ (channel)

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

  def close
  end

  # Not part of AMQP::Client::EM_CONNECTION_CLASS interface, for mock introspection only
  def callbacks
    @callbacks||=[]
  end

  def messages
    @messages||=[]
  end
end

# Sets expectations about @header and @body passed to @consumer.
def should_pass_updated_header_and_data_to consumer, opts={}
  # - Why update @header.properties if @header becomes nil anyways?'
  # - Because @consumer receives @header and may inspect its properties

  subject_mock(:@method).should_receive(:arguments).
      with(no_args).and_return(myprop: 'mine')
  consumer.should_receive(:receive) do |header, body|
    header.klass.should == (opts[:klass] || AMQP::Protocol::Test)
    header.size.should == (opts[:size] || 4)
    header.weight.should == (opts[:weight] || 2)
    header.properties.should == (opts[:properties] || {delivery_mode: 1, myprop: 'mine'})
    body.should == (opts[:body] || 'data')
  end
end

# Sets expectations that all listed instance variables for subject are nil
def should_be_nil *ivars
  ivars.each do |ivar|
    subject.instance_variable_get(ivar).should be_nil
  end
end
