# encoding: utf-8

require 'spec_helper'

require "multi_json"

describe "Concurrent publishing on a shared channel" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec

  default_timeout 10

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.should be_open
    @channel.on_error do |ch, close|
      raise "Channel-level error!: #{close.inspect}"
    end

    @queue1    = @channel.queue("amqpgem.tests.integration.queue#{Time.now.to_i}#{rand}", :exclusive => true)
    @queue2    = @channel.queue("amqpgem.tests.integration.queue#{Time.now.to_i}#{rand}", :exclusive => true)

    # Rely on default direct exchange binding, see section 2.1.2.4 Automatic Mode in AMQP 0.9.1 spec.
    @exchange = AMQP::Exchange.default(@channel)
  end


  default_options AMQP_OPTS

  let(:inputs) do
    [
     { :index=>{:_routing=>530,:_index=>"optimizer",:_type=>"earnings",:_id=>530}},
     { :total_conversions=>0,:banked_clicks=>0,:total_earnings=>0,:pending_conversions=>0,:paid_net_earnings=>0,:banked_conversions=>0,:pending_earnings=>0,:optimizer_id=>530,:total_impressions=>0,:banked_earnings=>0,:bounce_count=>0,:time_on_page=>0,:total_clicks=>0,:entrances=>0,:pending_clicks=>0,:paid_earnings=>0},

     { :index=>{:_routing=>430,:_index=>"optimizer",:_type=>"earnings",:_id=>430}},
     { :total_conversions=>1443,:banked_clicks=>882,:total_earnings=>5796.3315841537,:pending_conversions=>22,:paid_net_earnings=>4116.90224486802,:banked_conversions=>1086,:pending_earnings=>257.502767857143,:optimizer_id=>430,:total_impressions=>6370497,:banked_earnings=>122.139339285714,:bounce_count=>6825,:time_on_page=>0,:total_clicks=>38143,:entrances=>12336,:pending_clicks=>1528,:paid_earnings=>5670.78224486798},

     { :index=>{:_routing=>506,:_index=>"optimizer",:_type=>"earnings",:_id=>506}},
     { :total_conversions=>237,:banked_clicks=>232,:total_earnings=>550.6212071428588277,:pending_conversions=>9,:paid_net_earnings=>388.021207142857,:banked_conversions=>225,:pending_earnings=>150.91,:optimizer_id=>506,:total_impressions=>348319,:banked_earnings=>12.92,:bounce_count=>905,:time_on_page=>0,:total_clicks=>4854,:entrances=>1614,:pending_clicks=>1034,:paid_earnings=>537.501207142858},

     {:index=>{:_routing=>345,:_index=>"optimizer",:_type=>"earnings",:_id=>345}},
     {:total_conversions=>0,:banked_clicks=>0,:total_earnings=>0,:pending_conversions=>0,:paid_net_earnings=>0,:banked_conversions=>0,:pending_earnings=>0,:optimizer_id=>345,:total_impressions=>0,:banked_earnings=>0,:bounce_count=>0,:time_on_page=>0,:total_clicks=>0,:entrances=>0,:pending_clicks=>0,:paid_earnings=>0}
    ]
  end
  let(:messages) { inputs.map {|i| MultiJson.encode(i) } * 3 }

  it "frames bodies correctly" do
    @exchange.channel.should == @channel

    number_of_received_messages = 0
    expected_number_of_messages = 3
    dispatched_data             = "to be received by queue1"

    @queue1.subscribe do |payload|
      number_of_received_messages += 1
      payload.should == dispatched_data
    end # subscribe

    4.times do
      Thread.new do
        @exchange.publish(body, :routing_key => "killa key")
      end
    end

    expected_number_of_messages.times do
      Thread.new do
        @exchange.publish(dispatched_data,    :routing_key => @queue1.name)
      end
    end

    4.times do
      Thread.new do
        @exchange.publish(body, :routing_key => "killa key")
      end
    end

    delayed(0.6) {
      # We never subscribe to it, hence, need to delete manually
      @queue2.delete
    }

    done(5.0) {
      number_of_received_messages.should == expected_number_of_messages
    }
  end
end # describe
