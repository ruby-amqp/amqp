require 'spec_helper'

require 'eventmachine'
require 'amqp'

require 'amqp-spec'

describe AMQP::Client, ' when testing :reconnect_timer and :fallback_servers' do
#  include AMQP::SpecHelper

#  after do
#    Mocha::Mockery.instance.teardown
#    Mocha::Mockery.reset_instance
#    #TODO: these clean ups here should not be necessary!
#    Thread.current[:mq] = nil
#    AMQP.instance_eval{ @conn = nil }
#    AMQP.instance_eval{ @closing = false }
#  end

  it 'should reconnect on disconnect after connection_completed (use reconnect_timer)' do
    @times_connected = 0
    @connect_args = []

    EventMachine.stub(:connect_server) do |arg1, arg2|
      @connect_args << [arg1, arg2]
      @times_connected += 1
      EM.next_tick do
        @client = EM.class_eval { @conns }[99]
        @client.stub(:send_data).and_return(true)
        @client.connection_completed
        EM.class_eval { @conns.delete(99) }
        @client.unbind
      end
      99 # returns(99)
    end
    EM.next_tick { EM.add_timer(0.5) { EM.stop_event_loop } }

    #connect
    AMQP.start(:host => 'nonexistanthost', :reconnect_timer => 0.1)
    @connect_args.each do |(arg1, arg2)|
      arg1.should == "nonexistanthost"
      arg2.should == 5672
    end
    @times_connected.should == 5
  end

  it 'should reconnect on disconnect before connection_completed (use reconnect_timer)' do
    @times_connected = 0
    @connect_args = []

    EventMachine.stub(:connect_server) do |arg1, arg2|
      @connect_args << [arg1, arg2]
      @times_connected += 1
      EM.next_tick do
        @client = EM.class_eval { @conns }[99]
        @client.stub(:send_data).and_return(true)
        EM.class_eval { @conns.delete(99) }
        @client.unbind
      end
      99 # returns(99)
    end
    EM.next_tick { EM.add_timer(0.5) { EM.stop_event_loop } }

    #connect
    AMQP.start(:host => 'nonexistanthost', :reconnect_timer => 0.1)
    @times_connected.should == 5
    @connect_args.each do |(arg1, arg2)|
      arg1.should == "nonexistanthost"
      arg2.should == 5672
    end
  end

  it "should use fallback servers on reconnect" do
    @times_connected = 0
    @connect_args = []

    EventMachine.stub(:connect_server) do |arg1, arg2|
      @connect_args << [arg1, arg2]
      @times_connected += 1
      EM.next_tick do
        @client = EM.class_eval { @conns }[99]
        @client.stub(:send_data).and_return(true)
        EM.class_eval { @conns.delete(99) }
        @client.unbind
      end
      99 # returns(99)
    end
    EM.next_tick { EM.add_timer(0.5) { EM.stop_event_loop } }

    #connect
    AMQP.start(:host => 'nonexistanthost', :reconnect_timer => 0.1,
               :fallback_servers => [
                   {:host => 'alsononexistant'},
                   {:host => 'alsoalsononexistant', :port => 1234},
               ])
    # puts "\nreconnected #{@times_connected} times"
    @times_connected.should == 5
    # puts "@connect_args: " + @connect_args.inspect
    @connect_args.should == [
        ["nonexistanthost", 5672], ["alsononexistant", 5672], ["alsoalsononexistant", 1234],
        ["nonexistanthost", 5672], ["alsononexistant", 5672]]
  end

  it "should use fallback servers on reconnect when connection_completed" do
    @times_connected = 0
    @connect_args = []

    EventMachine.stub(:connect_server) do |arg1, arg2|
      @connect_args << [arg1, arg2]
      @times_connected += 1
      EM.next_tick do
        @client = EM.class_eval { @conns }[99]
        @client.stub(:send_data).and_return(true)
        @client.connection_completed
        EM.class_eval { @conns.delete(99) }
        @client.unbind
      end
      99 # returns(99)
    end
    EM.next_tick { EM.add_timer(0.5) { EM.stop_event_loop } }

    #connect
    AMQP.start(:host => 'nonexistanthost', :reconnect_timer => 0.1,
               :fallback_servers => [
                   {:host => 'alsononexistant'},
                   {:host => 'alsoalsononexistant', :port => 1234},
               ])
    # puts "\nreconnected #{@times_connected} times"
    @times_connected.should == 5
    # puts "@connect_args: " + @connect_args.inspect
    @connect_args.should == [
        ["nonexistanthost", 5672], ["alsononexistant", 5672], ["alsoalsononexistant", 1234],
        ["nonexistanthost", 5672], ["alsononexistant", 5672]]
  end
end
