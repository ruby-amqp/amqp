require 'spec_helper'
require 'amqp'

describe AMQP, 'as a class' do
#  include AMQP
  subject { AMQP }

  its(:logging) { should be_false }

#  it 'should initialize with data' do
#    Buffer.new('abc').contents.should == 'abc'
#  end

end