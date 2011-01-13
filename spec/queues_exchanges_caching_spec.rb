# encoding: utf-8

require File.expand_path("../spec_helper", __FILE__)

describe MQ::Queue do
  include AMQP::Spec

  default_timeout 5

  amqp_before do
    @mq = MQ.new
  end

  it "should return queue with given name if such queue already exist and if it has the same options" do
    queue = @mq.queue("test")
    @mq.queue("test").object_id.should eql(queue.object_id)
    done
  end

  it "should raise MQ::IncompatibleOptionsError if queue with the same name exists, but it has different options" do
    @mq.queue("test-2", :auto_delete => true)
    lambda {
      @mq.queue("test-2", :auto_delete => false)
    }.should raise_error(MQ::IncompatibleOptionsError)
    done
  end
end
