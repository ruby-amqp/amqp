# encoding: utf-8

require 'spec_helper'

describe AMQP::Channel do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_options AMQP_OPTS
  default_timeout 2


  amqp_before do
    @channel = AMQP::Channel.new
  end

  #
  # Examples
  #

  describe "exchange to exchange bindings" do
    context "basic properties" do
      it "bind returns self" do
        source1 = @channel.fanout("fanout-exchange-source-1")
        source2 = @channel.fanout("fanout-exchange-source-2")
        destination = @channel.fanout("fanout-exchange-destination-multi")
        destination.bind(source1).bind(source2).should == destination
        done
      end

      it "bind can work with strings for source exchange parameter" do
        @channel.fanout("fanout-exchange-source-3")
        destination = @channel.fanout("fanout-exchange-destination-multi-2")
        destination.bind('fanout-exchange-source-3').should == destination
        done
      end
    end

    context "fanout exchanges" do
      it "are bindable and forward messages" do
        source = @channel.fanout("fanout-exchange-source")
        destination = @channel.fanout("fanout-exchange-destination")
        messages = []
        destination.bind(source) do
          queue = @channel.queue("fanout-forwarding", :auto_delete => true)
          queue.subscribe do |metadata, payload|
            messages << payload
          end
          queue.bind(destination) do
            source.publish("x")
          end
        end
        done(0.1) { messages.should == ["x"] }
      end

      it "can be unbound" do
        source = @channel.fanout("fanout-exchange-source-2")
        destination = @channel.fanout("fanout-exchange-destination-2")
        destination.bind(source) do
          destination.unbind(source) do
            done
          end
        end
      end

      it "can be unbound without callbacks" do
        source = @channel.fanout("fanout-exchange-source-2")
        destination = @channel.fanout("fanout-exchange-destination-2")
        destination.bind(source)
        destination.unbind(source)
        done
      end

      it "using :nowait => true should not call a passed in block" do
        source = @channel.fanout("fanout-exchange-source-no-wait")
        destination = @channel.fanout("fanout-exchange-destination-no-wait")
        callback_called = false
        destination.bind(source, :nowait => true) do
          callback_called = true
        end
        done(0.1) { callback_called.should be_false}
      end

    end #context

    context "topic exchanges" do
      it "using routing key '#'" do
        source = @channel.topic("topic-exchange-source")
        destination = @channel.topic("topic-exchange-destination")
        messages = []
        destination.bind(source) do
          queue = @channel.queue("ex-to-ex-default-key", :auto_delete => true)
          queue.subscribe do |metadata, payload|
            messages << payload
          end
          queue.bind(destination, :routing_key => "#") do
            source.publish("a", :routing_key => "lalalala")
          end
        end
        done(0.1) { messages.should == ["a"] }
      end

      it "using routing key 'foo'" do
        source = @channel.topic("topic-exchange-source-foo")
        destination = @channel.topic("topic-exchange-destination-foo")
        messages = []
        destination.bind(source, :routing_key => 'foo') do
          queue = @channel.queue("foo-foo", :auto_delete => true)
          queue.subscribe do |metadata, payload|
            messages << payload
          end
          queue.bind(destination, :routing_key => "foo") do
            source.publish("b", :routing_key => "foo")
          end
        end
        done(0.1) { messages.should == ["b"]}
      end
    end #context
  end # describe
end # describe AMQP
