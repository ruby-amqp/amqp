# encoding: utf-8

require "spec_helper"

describe AMQP::Queue, "#pop" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper


  default_options AMQP_OPTS
  default_timeout 10

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.should be_open

    @queue_name = "amqpgem.integration.basic.get.queue"

    @exchange = @channel.fanout("amqpgem.integration.basic.get.queue", :auto_delete => true)
    @queue    = @channel.queue(@queue_name, :auto_delete => true)

    @queue.bind(@exchange)

    @dispatched_data = "fetch me synchronously"
  end



  #
  # Examples
  #

  context "when THERE ARE NO messages in the queue" do
    it "yields nil (instead of message payload) to the callback" do
      @queue.purge do
        callback_has_fired = false

        @queue.status do |number_of_messages, number_of_consumers|
          number_of_messages.should == 0
        end

        @queue.pop do |payload|
          callback_has_fired = true
          @queue.delete
          payload.should be_nil
        end

        done(0.2) {
          callback_has_fired.should be_true
        }
      end
    end
  end

  context "when THERE ARE messages in the queue" do
    it "yields message payload to the callback" do
      number_of_received_messages = 0
      expected_number_of_messages = 300

      expected_number_of_messages.times do |i|
        @exchange.publish(@dispatched_data + "_#{i}", :key => @queue_name)
      end

      @queue.status do |number_of_messages, number_of_consumers|
        expected_number_of_messages.times do
          @queue.pop do |headers, payload|
            payload.should_not be_nil
            number_of_received_messages += 1
            headers.message_count.should == (expected_number_of_messages - number_of_received_messages)

            if RUBY_VERSION =~ /^1.9/
              payload.force_encoding("UTF-8").should =~ /#{@dispatched_data}/
            else
              payload.should =~ /#{@dispatched_data}/
            end
          end # pop
        end # do
      end

      delayed(1.3) {
        # Queue.Get doesn't qualify for subscription, hence, manual deletion is required
        @queue.delete
      }
      done(2.5) {
        number_of_received_messages.should == expected_number_of_messages
      }
    end # it
  end # context


  context "with manual acknowledgements" do
    default_timeout 4

    let(:queue_name) { "amqpgem.integration.basic.get.acks.manual#{rand}" }

    it "does not remove messages from the queue unless ack-ed" do
      ch1 = AMQP::Channel.new
      ch2 = AMQP::Channel.new

      ch1.on_error do |ch, close_ok|
        puts "Channel error: #{close_ok.reply_code} #{close_ok.reply_text}"
      end

      q  = ch1.queue(queue_name, :exclusive => true)
      x  = ch1.default_exchange

      q.purge
      x.publish(@dispatched_data, :routing_key => q.name)

      delayed(0.5) {
        q.pop(:ack => true) do |meta, payload|
          # never ack
        end

        ch1.close

        EventMachine.add_timer(0.5) {
          ch2.queue(queue_name, :exclusive => true).status do |number_of_messages, number_of_consumers|
            number_of_messages.should == 1
            done
          end
        }
      }
    end
  end



  context "with automatic acknowledgements" do
    default_timeout 4

    let(:queue_name) { "amqpgem.integration.basic.get.acks.automatic#{rand}" }

    it "does remove messages from the queue after delivery" do
      ch1 = AMQP::Channel.new
      ch2 = AMQP::Channel.new

      ch1.on_error do |ch, close_ok|
        puts "Channel error: #{close_ok.reply_code} #{close_ok.reply_text}"
      end

      q  = ch1.queue(queue_name, :exclusive => true)
      x  = ch1.default_exchange

      q.purge
      x.publish(@dispatched_data, :routing_key => q.name)

      delayed(0.5) {
        q.pop(:ack => false) do |meta, payload|
          # never ack
        end

        ch1.close

        EventMachine.add_timer(0.5) {
          ch2.queue(queue_name, :exclusive => true).status do |number_of_messages, number_of_consumers|
            number_of_messages.should == 0
            done
          end
        }
      }
    end
  end

end # describe
