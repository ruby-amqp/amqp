# encoding: utf-8

require 'spec_helper'

describe AMQP::Queue do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 5



  #
  # Examples
  #

  describe "#status" do
    it "yields # of messages & consumers to the callback" do
      events  = []
      channel = AMQP::Channel.new

      queue1 = channel.queue("", :auto_delete => true)
      queue2 = channel.queue("amqpgem.tests.a.named.queue", :auto_delete => true)

      EventMachine.add_timer(1.0) do
        queue1.status do |m, c|
          events << :queue1_declare_ok
        end
        queue2.status do |m, c|
          events << :queue2_declare_ok
        end        
      end

      done(2.0) {
        events.should include(:queue1_declare_ok)
        events.should include(:queue2_declare_ok)
      }
    end


    it "yields # of messages & consumers to the callback in pseudo-synchronous code" do
      events  = []
      channel = AMQP::Channel.new

      queue1 = channel.queue("", :auto_delete => true)
      queue2 = channel.queue("amqpgem.tests.a.named.queue", :auto_delete => true)

      queue1.status do |m, c|
        events << :queue1_declare_ok
      end
      queue2.status do |m, c|
        events << :queue2_declare_ok
      end

      done(2.0) {
        queue1.name.should =~ /^amq\..+/
        events.should include(:queue1_declare_ok)
        events.should include(:queue2_declare_ok)
      }
    end
  end
end
