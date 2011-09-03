# encoding: utf-8

require 'spec_helper'

unless ENV["CI"]
  describe "Message acknowledgements" do

    #
    # Environment
    #

    include EventedSpec::AMQPSpec

    default_timeout 120

    amqp_before do
      @connection = AMQP.connect
      @channel1   = AMQP::Channel.new(@connection)
      @channel2   = AMQP::Channel.new(@connection)
    end


    it "can be issued for delivery tags >= 192" do
      exchange_name = "amqpgem.tests.fanout#{rand}"
      queue         = @channel1.queue("", :auto_delete => true).bind(exchange_name).subscribe(:ack => true) do |metadata, payload|
        puts "x-sequence = #{metadata.headers['x-sequence']}, delivery_tag = #{metadata.delivery_tag}" if ENV["DEBUG"]
        metadata.ack
        if metadata.delivery_tag >= 999
          done(1.0)
        end
      end

      exchange = @channel2.fanout(exchange_name, :durable => false)
      2000.times do |i|
        exchange.publish("", :headers => { 'x-sequence' => i })
      end
    end
  end  
end