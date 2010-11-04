require 'spec_helper'
require 'amqp-spec/rspec'

require 'mq'

#module MockClientModule
#  def my_mock_method
#  end
#end
#
#class MockClient
#  include AMQP::Client
#end

describe 'MQ', 'as a class' do

#  context 'has class accessors, with default values' do
#    subject { AMQP }
#
#    its(:logging) { should be_false }
#    its(:connection) { should be_nil }
#    its(:conn) { should be_nil } # Alias for #connection
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
#  end
#
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