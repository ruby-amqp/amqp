# encoding: utf-8

require "spec_helper"

include PlatformDetection

# Only run this for MRI.
#
# rubinius implementation of ThreadGroup has a bug: it references objects without checking
# whether they are alive. So sandbox this test for other Rubies for now. Per discussion with
# brixen in #travis, see also https://gist.github.com/1100572.
#
# JRuby is having weird CI issues, too. Still investigating them. MK.
if mri?
  describe "Concurrent publishing on a shared channel from multiple threads" do

    #
    # Environment
    #

    include EventedSpec::AMQPSpec
    default_options AMQP_OPTS
    default_timeout 15

    amqp_before do
      @channel   = AMQP::Channel.new
      @channel.on_error do |ch, close|
        raise "Channel-level error!: #{close.inspect}"
      end
      @channel.connection.on_error do |conn, connection_close|
        raise "Handling a connection-level exception: #{connection_close.reply_text}"
      end
    end


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



    #
    # Examples
    #

    it "DOES NOT result in frames being delivered out of order (no UNEXPECTED_FRAME connection exceptions)" do
      received_messages = []
      queue    = @channel.queue("amqpgem.tests.concurrent_publishing", :auto_delete => true)
      exchange = @channel.default_exchange
      exchange.on_return do |method, header, body|
        puts "Message was returned: #{method.reply_text}"
      end

      queue.subscribe do |metadata, payload|
        received_messages << payload
      end

      EventMachine.add_timer(2.0) do
        # ZOMG THREADS!
        20.times do
          Thread.new do
            messages.each do |message|
              exchange.publish(message, :routing_key => queue.name, :mandatory => true)
            end
          end
        end
      end


      # let it run for several seconds because you know, concurrency issues do not always manifest themselves
      # immediately. MK.
      done(14.0) {
        # we don't care about the exact number of messages sent or received, just the fact that there are
        # no UNEXPECTED_FRAME connection-level exceptions. MK.
      }
    end
  end
end
