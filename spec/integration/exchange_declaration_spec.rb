# encoding: utf-8

require 'spec_helper'

describe AMQP do

  #
  # Environment
  #

  include AMQP::Spec

  default_timeout 10

  amqp_before do
    @channel = AMQP::Channel.new
  end


  #
  # Examples
  #

  describe "#direct" do
    context "when exchange name is specified" do
      it 'declares a new direct exchange with that name' do
        @channel.direct('name').name.should == 'name'

        done
      end

      it "declares direct exchange as transient (non-durable)" do
        exchange = @channel.direct('name')

        exchange.should_not be_durable
        exchange.should be_transient

        done
      end

      it "declares direct exchange as non-auto-deleted" do
        exchange = @channel.direct('name')

        exchange.should_not be_auto_deleted

        done
      end
    end


    context "when exchange name is omitted" do
      it 'uses amq.direct' do
        @channel.direct.name.should == 'amq.direct'
        done
      end # it
    end # context


    context "when exchange name was specified as a blank string" do
      it 'returns direct exchange with server-generated name' do
        pending <<-EOF
      This has to be fixed in RabbitMQ first
      https://bugzilla.rabbitmq.com/show_bug.cgi?id=23509
    EOF
        @channel.direct("") do |exchange|
          exchange.name.should_not be_empty
          done
        end
      end
    end # context


    context "when passive option is used" do
      context "and exchange with given name already exists" do
        it "silently returns" do
          name = "a_new_direct_exchange declared at #{Time.now.to_i}"

          original_exchange = @channel.direct(name)
          exchange          = @channel.direct(name, :passive => true)

          exchange.should == original_exchange

          done
        end # it
      end

      context "and exchange with given name DOES NOT exist" do
        it "raises an exception" do
          pending "Not yet supported"

          expect {
            exchange = @channel.direct("direct exchange declared at #{Time.now.to_i}", :passive => true)
          }.to raise_error

          done
        end # it
      end # context
    end # context


    context "when exchange is declared as durable" do
      it "returns a new durable direct exchange" do
        exchange = @channel.direct("a_new_durable_direct_exchange", :durable => true)
        exchange.should be_durable
        exchange.should_not be_transient

        done
      end # it
    end # context


    context "when exchange is declared as non-durable" do
      it "returns a new NON-durable direct exchange" do
        exchange = @channel.direct("a_new_non_durable_direct_exchange", :durable => false)
        exchange.should_not be_durable
        exchange.should be_transient

        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted direct exchange" do
        exchange = @channel.direct("a new auto-deleted direct exchange", :auto_delete => true)

        exchange.should be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted direct exchange" do
        exchange = @channel.direct("a new non-auto-deleted direct exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared without explicit :nowait parameter" do
      it "is declared with :nowait by default" do
        exchange = @channel.direct("a new non-auto-deleted direct exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is re-declared with parameters different from original declaration" do
      it "raises an exception" do
        @channel.direct("previously.declared.durable.direct.exchange", :durable => true)

        expect {
          @channel.direct("previously.declared.durable.direct.exchange", :durable => false)
        }.to raise_error(AMQP::IncompatibleOptionsError)

        done
      end # it
    end # context
  end # describe




  describe "#fanout" do
    context "when exchange name is specified" do
      let(:name) { "new.fanout.exchange" }

      it "declares a new fanout exchange with that name" do
        exchange = @channel.fanout(name)

        exchange.name.should == name

        done
      end
    end # context

    context "when exchange name is omitted" do
      it "uses amq.fanout" do
        exchange = @channel.fanout
        exchange.name.should == "amq.fanout"
        exchange.name.should_not == "amq.fanout2"

        done
      end
    end # context

    context "when passive option is used" do
      context "and exchange with given name already exists" do
        it "silently returns" do
          name = "a_new_fanout_exchange declared at #{Time.now.to_i}"

          original_exchange = @channel.fanout(name)
          exchange          = @channel.fanout(name, :passive => true)

          exchange.should == original_exchange

          done
        end # it
      end

      context "and exchange with given name DOES NOT exist" do
        it "raises an exception" do
          pending "Not yet supported"

          expect {
            exchange = @channel.fanout("fanout exchange declared at #{Time.now.to_i}", :passive => true)
          }.to raise_error

          done
        end # it
      end # context
    end # context


    context "when exchange is declared as durable" do
      it "returns a new durable fanout exchange" do
        exchange = @channel.fanout("a_new_durable_fanout_exchange", :durable => true)
        exchange.should be_durable
        exchange.should_not be_transient

        done
      end # it
    end # context


    context "when exchange is declared as non-durable" do
      it "returns a new NON-durable fanout exchange" do
        exchange = @channel.fanout("a_new_non_durable_fanout_exchange", :durable => false)
        exchange.should_not be_durable
        exchange.should be_transient

        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted fanout exchange" do
        exchange = @channel.fanout("a new auto-deleted fanout exchange", :auto_delete => true)

        exchange.should be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted fanout exchange" do
        exchange = @channel.fanout("a new non-auto-deleted fanout exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared without explicit :nowait parameter" do
      it "is declared with :nowait by default" do
        exchange = @channel.fanout("a new non-auto-deleted fanout exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is re-declared with parameters different from original declaration" do
      it "raises an exception" do
        @channel.fanout("previously.declared.durable.topic.exchange", :durable => true)

        expect {
          @channel.fanout("previously.declared.durable.topic.exchange", :durable => false)
        }.to raise_error(AMQP::IncompatibleOptionsError)

        done
      end # it
    end # context
  end # describe




  describe "#topic" do
    context "when exchange name is specified" do
      let(:name) { "a.topic.exchange" }

      it "declares a new topic exchange with that name" do
        exchange = @channel.topic(name)
        exchange.name.should == name

        done
      end
    end # context

    context "when exchange name is omitted" do
      it "uses amq.topic" do
        exchange = @channel.topic
        exchange.name.should == "amq.topic"
        exchange.name.should_not == "amq.topic2"

        done
      end
    end # context

    context "when passive option is used" do
      context "and exchange with given name already exists" do
        it "silently returns" do
          name = "a_new_topic_exchange declared at #{Time.now.to_i}"

          original_exchange = @channel.topic(name)
          exchange          = @channel.topic(name, :passive => true)

          exchange.should == original_exchange

          done
        end # it
      end

      context "and exchange with given name DOES NOT exist" do
        it "raises an exception" do
          pending "Not yet supported"

          expect {
            exchange = @channel.topic("topic exchange declared at #{Time.now.to_i}", :passive => true)
          }.to raise_error

          done
        end # it
      end # context
    end # context


    context "when exchange is declared as durable" do
      it "returns a new durable topic exchange" do
        exchange = @channel.topic("a_new_durable_topic_exchange", :durable => true)
        exchange.should be_durable
        exchange.should_not be_transient

        done
      end # it
    end # context


    context "when exchange is declared as non-durable" do
      it "returns a new NON-durable topic exchange" do
        exchange = @channel.topic("a_new_non_durable_topic_exchange", :durable => false)
        exchange.should_not be_durable
        exchange.should be_transient

        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted topic exchange" do
        exchange = @channel.topic("a new auto-deleted topic exchange", :auto_delete => true)

        exchange.should be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted topic exchange" do
        exchange = @channel.topic("a new non-auto-deleted topic exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared without explicit :nowait parameter" do
      it "is declared with :nowait by default" do
        exchange = @channel.topic("a new non-auto-deleted topic exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is re-declared with parameters different from original declaration" do
      amqp_after do
        done
      end

      it "raises an exception" do
        channel = AMQP::Channel.new

        channel.topic("previously.declared.durable.topic.exchange", :durable => true)
        channel.should be_open

        expect {
          channel.topic("previously.declared.durable.topic.exchange", :durable => false)
        }.to raise_error(AMQP::IncompatibleOptionsError)

        done
      end # it
    end # context
  end # describe




  describe "#headers" do
    context "when exchange name is specified" do
      let(:name) { "new.headers.exchange" }

      it "declares a new headers exchange with that name" do
        exchange = @channel.headers(name)

        exchange.name.should == name

        done
      end
    end # context

    context "when exchange name is omitted" do
      xit "uses amq.match" do
        pending "Times out. MK."

        exchange = @channel.headers
        exchange.name.should == "amq.match"
        exchange.name.should_not == "amq.headers"

        done
      end
    end # context

    context "when passive option is used" do
      context "and exchange with given name already exists" do
        it "silently returns" do
          name = "a_new_headers_exchange declared at #{Time.now.to_i}"

          original_exchange = @channel.headers(name)
          exchange          = @channel.headers(name, :passive => true)

          exchange.should == original_exchange

          done
        end # it
      end

      context "and exchange with given name DOES NOT exist" do
        it "raises an exception" do
          pending "Not yet supported"

          expect {
            exchange = @channel.headers("headers exchange declared at #{Time.now.to_i}", :passive => true)
          }.to raise_error

          done
        end # it
      end # context
    end # context


    context "when exchange is declared as durable" do
      it "returns a new durable headers exchange" do
        exchange = @channel.headers("a_new_durable_headers_exchange", :durable => true)
        exchange.should be_durable
        exchange.should_not be_transient

        done
      end # it
    end # context


    context "when exchange is declared as non-durable" do
      it "returns a new NON-durable headers exchange" do
        exchange = @channel.headers("a_new_non_durable_headers_exchange", :durable => false)
        exchange.should_not be_durable
        exchange.should be_transient

        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted headers exchange" do
        exchange = @channel.headers("a new auto-deleted headers exchange", :auto_delete => true)

        exchange.should be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted headers exchange" do
        exchange = @channel.headers("a new non-auto-deleted headers exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared without explicit :nowait parameter" do
      it "is declared with :nowait by default" do
        exchange = @channel.headers("a new non-auto-deleted headers exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is re-declared with parameters different from original declaration" do
      xit "raises an exception" do
        pending "Times out. MK."
        @channel.headers("previously.declared.durable.topic.exchange", :durable => true)

        expect {
          @channel.headers("previously.declared.durable.topic.exchange", :durable => false)
        }.to raise_error(AMQP::IncompatibleOptionsError)

        done
      end # it
    end # context
  end # describe
end # describe AMQP
