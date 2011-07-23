# encoding: utf-8
require 'spec_helper'

unless ENV["CI"]
  describe "Per-channel automatic channel recovery" do

    #
    # Environment
    #

    include RabbitMQ::Control

    include EventedSpec::AMQPSpec
    default_timeout 20.0

    amqp_before do
      @channel = AMQP::Channel.new(AMQP.connection, :auto_recovery => true)
    end


    after :all do
      start_rabbitmq unless rabbitmq_pid
    end

    # ...


    #
    # Examples
    #

    it "can be used when broker is shut down gracefully" do
      AMQP.connection.on_error do |conn, connection_close|
        puts "[connection.close] Reply code = #{connection_close.reply_code}, reply text = #{connection_close.reply_text}"
        if connection_close.reply_code == 320
          puts "[connection.close] Setting up a periodic reconnection timer..."
          conn.periodically_reconnect(1)
        end
      end

      pid = rabbitmq_pid
      puts "rabbitmq pid = #{pid.inspect}"

      stop_rabbitmq
      rabbitmq_pid.should be_nil

      # 2 seconds later, check that we are reconnecting
      EventMachine.add_timer(2.0) do
        AMQP.connection.should_not be_connected
        AMQP.connection.should be_reconnecting
      end


      # 4 seconds later, start RabbitMQ
      EventMachine.add_timer(4.0) do
        start_rabbitmq
        rabbitmq_pid.should_not be_nil
      end

      # 10 seconds later, use the (now recovered) connection. Note that depending
      # on # of plugins used it may take 5-10 seconds to start up RabbitMQ and initialize it,
      # then open a new AMQP connection. That's why we wait. MK.
      EventMachine.add_timer(10.0) do
        AMQP.connection.should be_connected
        AMQP.connection.should_not be_reconnecting

        @channel.queue("amqpgem.tests.a.queue", :auto_delete => true).subscribe do |metadata, payload|
          puts "Got a message: #{payload.inspect}"
          done
        end

        EventMachine.add_timer(1.5) { @channel.default_exchange.publish("", :routing_key => "amqpgem.tests.a.queue") }
      end
    end
  end
end
