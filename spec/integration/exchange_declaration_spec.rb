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


  describe "default exchange" do
    subject do
      @channel.default_exchange
    end

    it "is predefined" do
      subject.should be_predefined
      done
    end
  end

  describe "exchange named amq.direct" do
    subject do
      @channel.direct("amq.direct")
    end

    it "is predefined" do
      subject.should be_predefined
      done
    end
  end

  describe "exchange named amq.fanout" do
    subject do
      @channel.direct("amq.fanout")
    end

    it "is predefined" do
      subject.should be_predefined
      done
    end
  end

  describe "exchange named amq.topic" do
    subject do
      @channel.direct("amq.topic")
    end

    it "is predefined" do
      subject.should be_predefined
      done
    end
  end

  describe "exchange named amq.match" do
    subject do
      @channel.direct("amq.match")
    end

    it "is predefined" do
      subject.should be_predefined
      done
    end
  end

  describe "exchange named amq.headers" do
    subject do
      @channel.direct("amq.headers")
    end

    it "is predefined" do
      subject.should be_predefined
      done
    end
  end



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


    context "when passive option is used" do
      context "and exchange with given name already exists" do
        it "silently returns" do
          name    = "a_new_direct_exchange declared at #{Time.now.to_i}"
          channel = AMQP::Channel.new

          original_exchange = channel.direct(name)
          exchange          = channel.direct(name, :passive => true)

          exchange.should == original_exchange

          done
        end # it
      end

      context "and exchange with given name DOES NOT exist" do
        it "raises an exception" do
          channel = AMQP::Channel.new
          channel.on_error do |ch, channel_close|
            @error_code = channel_close.reply_code
          end

          exchange = channel.direct("direct exchange declared at #{Time.now.to_i}", :passive => true)

          done(0.5) {
            @error_code.should == 404
          }
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
        channel = AMQP::Channel.new
        channel.direct("previously.declared.durable.direct.exchange", :durable => true)

        expect {
          channel.direct("previously.declared.durable.direct.exchange", :durable => false)
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

    context "when exchange name is specified and :nowait is false" do
      let(:name) { "new.fanout.exchange#{rand}" }

      it "declares a new fanout exchange with that name" do
        exchange = @channel.fanout(name, :nowait => false)

        exchange.delete

        done(0.5) {
          exchange.name.should == name
        }
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
        it "results in a channel exception" do
          channel = AMQP::Channel.new
          channel.on_error do |ch, channel_close|
            @error_code = channel_close.reply_code
          end

          exchange = channel.fanout("fanout exchange declared at #{Time.now.to_i}", :passive => true)

          done(0.5) {
            @error_code.should == 404
          }

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
        channel = AMQP::Channel.new
        channel.fanout("previously.declared.durable.topic.exchange", :durable => true)

        expect {
          channel.fanout("previously.declared.durable.topic.exchange", :durable => false)
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
      end # it
    end # context

    context "when exchange name is omitted" do
      it "uses amq.topic" do
        exchange = @channel.topic
        exchange.name.should == "amq.topic"
        exchange.name.should_not == "amq.topic2"

        done
      end # it
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
      end # context

      context "and exchange with given name DOES NOT exist" do
        it "results in a channel exception" do
          channel = AMQP::Channel.new
          channel.on_error do |ch, channel_close|
            @error_code = channel_close.reply_code
          end

          exchange = channel.topic("topic exchange declared at #{Time.now.to_i}", :passive => true)

          done(0.5) {
            @error_code.should == 404
          }
        end # it
      end # context
    end


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

    context "when exchange is declared with or without :internal parameter" do
      it "should create a public exchange by default" do
        exchange = @channel.topic("a new public topic exchange")

        exchange.should_not be_internal
        done
      end # it

      it "should create a public exchange when :internal is false" do
        exchange = @channel.topic("a new-public topic exchange", :internal => false)

        exchange.should_not be_internal
        done
      end # it

      it "should create an internal exchange when :internal is true" do
        exchange = @channel.topic("a new internal topic exchange", :internal => true)

        exchange.should be_internal
        done
      end # it
    end # context

    context "when exchange is re-declared with parameters different from the original declaration" do
      amqp_after do
        done
      end

      it "raises an exception" do
        channel = AMQP::Channel.new
        channel.topic("previously.declared.durable.topic.exchange", :durable => true)

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
        channel  = AMQP::Channel.new
        exchange = channel.headers(name)

        exchange.name.should == name

        done
      end
    end # context

    context "when exchange name is omitted" do
      amqp_after do
        done
      end

      it "uses amq.match" do
        channel  = AMQP::Channel.new
        exchange = channel.headers
        exchange.name.should == "amq.match"
        exchange.name.should_not == "amq.headers"

        done
      end
    end # context

    context "when passive option is used" do
      context "and exchange with given name already exists" do
        it "silently returns" do
          name    = "a_new_headers_exchange declared at #{Time.now.to_i}"
          channel = AMQP::Channel.new

          original_exchange = channel.headers(name)
          exchange          = channel.headers(name, :passive => true)

          exchange.should == original_exchange

          done
        end # it
      end

      context "and exchange with given name DOES NOT exist" do
        it "raises an exception" do
          channel = AMQP::Channel.new
          channel.on_error do |ch, channel_close|
            @error_code = channel_close.reply_code
          end

          exchange = channel.headers("headers exchange declared at #{Time.now.to_i}", :passive => true)

          done(0.5) {
            @error_code.should == 404
          }
        end # it
      end # context
    end # context


    context "when exchange is declared as durable" do
      it "returns a new durable headers exchange" do
        channel  = AMQP::Channel.new
        exchange = channel.headers("a_new_durable_headers_exchange", :durable => true)
        exchange.should be_durable
        exchange.should_not be_transient

        done
      end # it
    end # context


    context "when exchange is declared as non-durable" do
      it "returns a new NON-durable headers exchange" do
        channel  = AMQP::Channel.new
        exchange = channel.headers("a_new_non_durable_headers_exchange", :durable => false)
        exchange.should_not be_durable
        exchange.should be_transient

        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted headers exchange" do
        channel  = AMQP::Channel.new
        exchange = channel.headers("a new auto-deleted headers exchange", :auto_delete => true)

        exchange.should be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared as auto-deleted" do
      it "returns a new auto-deleted headers exchange" do
        channel  = AMQP::Channel.new
        exchange = channel.headers("a new non-auto-deleted headers exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is declared without explicit :nowait parameter" do
      it "is declared with :nowait by default" do
        channel  = AMQP::Channel.new
        exchange = channel.headers("a new non-auto-deleted headers exchange", :auto_delete => false)

        exchange.should_not be_auto_deleted
        done
      end # it
    end # context


    context "when exchange is re-declared with parameters different from original declaration on the same channel" do
      amqp_after do
        done
      end

      it "raises an exception" do
        channel = AMQP::Channel.new
        channel.headers("previously.declared.durable.headers.exchange", :durable => true)

        expect {
          channel.headers("previously.declared.durable.headers.exchange", :durable => false)
        }.to raise_error(AMQP::IncompatibleOptionsError)

        done
      end # it
    end # context
  end # describe
end # describe AMQP
