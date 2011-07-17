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

    it "kicks in when broker goes down" do
      AMQP.connection.on_tcp_connection_loss do |conn, settings|
        puts "[network failure] Trying to reconnect..."
        conn.reconnect(false, 1)
      end

      pid = rabbitmq_pid
      puts "rabbitmq pid = #{pid.inspect}"

      kill_rabbitmq
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

      # 12 seconds later, use the (now recovered) connection. Note that depending
      # on # of plugins used it may take 5-10 seconds to start up RabbitMQ and initialize it,
      # then open a new AMQP connection. That's why we wait. MK.
      EventMachine.add_timer(12.0) do
        AMQP.connection.should be_connected
        AMQP.connection.should_not be_reconnecting

        @channel.queue("amqpgem.tests.a.queue", :auto_delete => true).subscribe do |metadata, payload|
          puts "Got a message"
          done
        end

        EventMachine.add_timer(1.5) { @channel.default_exchange.publish("Hi", :routing_key => "amqpgem.tests.a.queue") }
      end
    end
  end
end