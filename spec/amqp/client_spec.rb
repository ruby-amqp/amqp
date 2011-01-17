# encoding: utf-8

require File.expand_path("../../spec_helper", __FILE__)
require 'amqp/client'

describe AMQP::Client do
  include AMQP::SpecHelper
  include AMQP

  em_after { AMQP.cleanup_state }

  context 'with AMQP.client set to BasicClient (default)' do
    describe 'creating new connection to AMQP broker using .connect:', :broker => true do
      it 'when .connect is called outside EM event loop, raises error' do
        expect { Client.connect }.to raise_error /eventmachine not initialized/
      end

      context 'when .connect is called inside EM event loop:' do
        include AMQP::SpecHelper

        it 'calls EM.connect with AMQP::Client as a handler class and AMQP options, and' do
          em do
            opts = AMQP.settings.merge(AMQP_OPTS)
            EM.should_receive(:connect).with(opts[:host], opts[:port], Client, opts)
            Client.connect AMQP_OPTS
            done
          end
        end

        it 'either hits connection timeout (with :timeout option), or' do
          expect { em do
            Client.connect(:host => 'example.com', :timeout => 0.001)
            done(2)
          end
          }.to raise_error AMQP::Error, /Could not connect to server example.com:5672/
        end

        it 'raises connection error (with unresolvable AMQP broker address), or' do
          pending 'Need to rewrite to eliminate dependency on DNS loockup mechanism'
          expect { em do
            Client.connect(:host => 'impossible.')
            done(2)
          end
          }.to raise_error EventMachine::ConnectionError, /unable to resolve server address/
        end

        it 'raises connection error (with wrong AMQP host), or' do
          pending 'Need to rewrite to eliminate dependency on DNS loockup mechanism'
          expect { em do
            Client.connect(:host => 'example.com')
            done(2)
          end
          }.to raise_error AMQP::Error, /Could not connect to server example.com:5672/
        end

        it 'raises connection error (with wrong AMQP port), or' do
          expect { em do
            Client.connect(:port => 131313)
            done(2)
          end
          }.to raise_error AMQP::Error, /Could not connect to server 127.0.0.1:131313/
        end

        it 'returns client connecting to AMQP broker (with correct AMQP opts) - DELAY!' do
          em do
            client = Client.connect AMQP_OPTS
            client.should_not be_connected
            done(0.2) { client.should be_connected }
          end
        end

        context 'when connection is attempted, initiated client:' do
          include AMQP::EMSpec
          em_before { @client = Client.connect AMQP_OPTS }

          specify { @client.should_not be_connected; done }

          context "after a delay, connection is established and the client:" do
            it 'receives #connection_completed call from EM reactor' do
              @client.should_receive(:connection_completed).with(no_args)
              done(0.2)
            end

            it 'fires @connection_status block (if any) with :connected' do
              # Set up status processing block first
              @client.connection_status { |status| @status = status }
              done(0.2) { @status.should == :connected }
            end

            it 'becomes connected' do
              done(0.2) { @client.should be_connected }
            end
          end
        end

      end # context 'when .connect is called inside EM event loop:
    end # creating new connection to AMQP broker using .connect

    context 'given a client that is attempting to connect to AMQP broker using AMQP_OPTS' do
      include AMQP::EMSpec
      em_before { @client = Client.connect AMQP_OPTS }
      subject { @client }

      describe 'closing down' do
        context 'calling #close' do
          it 'just sets callback (to close connection) if @client is not yet connected' do
            @client.should_not be_connected
            @client.should_not_receive(:send)
            @client.should_receive(:callback)
            @client.close
            done
          end

          context 'if @client is connected'
          it 'closes all channels first if there are any' do
            EM.add_timer(0.2) {
              @client.should be_connected
              channel1 = MQ.new(@client)
              channel2 = MQ.new(@client)
              channel1.should_receive(:close)
              channel2.should_receive(:close)
              @client.close
              done }
          end

          it 'sends Protocol::Connection::Close method to broker' do
            EM.add_timer(0.2) {
              @client.should be_connected
              @client.should_receive(:send) do |message|
                message.should be_a Protocol::Connection::Close
              end
              @client.close
              done }
          end
        end # 'calling #close'

        context 'after broker responded to connection close request' do
          it 'client receives Protocol::Connection::CloseOk method from broker' do
            EM.add_timer(0.2) {
              @client.should_receive(:process_frame) do |frame|
                frame.payload.should be_a Protocol::Connection::CloseOk
              end
              @client.close
              done(0.2) }
          end

          it 'calls block given to #close instead of pre-set callbacks' do
            # stub it BEFORE #connection_completed fired!
            @client.should_not_receive(:disconnected)
            @client.should_not_receive(:reconnect)
            EM.add_timer(0.2) {
              @client.close { @on_disconnect_called = true }
              done(0.2) { @on_disconnect_called.should be_true } }
          end

          context 'if no block was given to #close' do

            it 'calls registered @on_disconnect hook' do
              EM.add_timer(0.2) {
                mock = mock('on_disconnect')
                mock.should_receive(:call).with(no_args)

                # subject_mock trips something and drops connection :(
                @client.instance_exec { @on_disconnect = mock }
                @client.close
                done(0.2) }
            end

            it 'normally, @on_disconnect just calls private #disconnected method' do
              # stub it BEFORE #connection_completed fired!
              @client.should_receive(:disconnected)
              EM.add_timer(0.2) { @client.close; done(0.2) }
            end

            it 'fires @connection_status block (if any) with :disconnected' do
              EM.add_timer(0.2) {
                  # Set up status processing block first
                @client.connection_status { |status| @status = status }
                @client.close
                done(0.2) { @status.should == :disconnected } }
            end

            it 'attempts to reconnect' do
              @client.should_receive(:reconnect)
              EM.add_timer(0.2) { @client.close; done(0.2) }
            end
          end # if no block was given to #close
        end # after broker responded to connection close request

        context '#unbind' do
          it 'is a hook method called by EM when network connection is dropped' do
            @client.should_receive(:unbind).with(no_args)
            @client.close
            done
          end

          it 'unsets @connected status' do
            EM.add_timer(0.1) {
              @client.should be_connected
              @client.unbind
              @client.should_not be_connected
              done }
          end

          it 'seems that it implicitly calls #connection_completed' do
            @client.should_receive(:connection_completed) do
              @client.instance_exec do
                # Avoid raising exception
                @on_disconnect = method(:disconnected)
              end
            end
            @client.unbind
            done
          end

          it 'calls @on_disconnect hook' do
            block_fired = false
            EM.add_timer(0.1) {
              @client.instance_exec do
                @on_disconnect = proc { block_fired = true }
              end
              @client.unbind
              done(0.1) { block_fired.should be_true } }
          end
        end
      end # closing down

      context 'reconnecting' do
        include AMQP::EMSpec

        it 're-initializes the client' do
          @client.should_receive(:initialize)
          @client.reconnect
          done
        end

        it 'resets and clears existing channels, if any' do
          channel1 = MQ.new(@client)
          channel2 = MQ.new(@client)
          EM.add_timer(0.2) {
            channel1.should_receive(:reset)
            channel2.should_receive(:reset)
            @client.reconnect
            @client.channels.should == {}
            done
          }
        end

        it 'reconnects to broker through EM.reconnect' do
          EM.should_receive(:reconnect)
          @client.reconnect
          done
        end

        it 'delays reconnect attempt by 1 sec if reconnect is already in progress' do
          EM.should_receive(:reconnect).exactly(1).times
          EM.should_receive(:add_timer).with(1)
          @client.reconnect
          @client.reconnect
          done
        end

        it 'attempts to automatically reconnect on #close' do
          @client.should_receive(:reconnect)
          EM.add_timer(0.2) { @client.close; done(0.2) }
        end
      end

      context 'receiving data/processing frames' do
        describe "#receive_data" do
          it 'is a callback method that EM calls when it gets raw data from broker' do
            @client.should_receive(:receive_data) do |data|
              frame = Frame.parse(data)
              frame.should be_an Frame::Method
              frame.payload.should be_an Protocol::Connection::Start
              done
            end
          end

          it 'delegates actual frame processing to #process_frame' do
            EM.add_timer(0.2) {
              @client.should_receive(:process_frame).with(basic_header)
              @client.receive_data(basic_header.to_s)
              done }
          end

          it 'does not call #process_frame on incomplete frames' do
            EM.add_timer(0.2) {
              @client.should_not_receive(:process_frame)
              @client.receive_data(basic_header.to_s[0..5])
              done }
          end

          it 'calls #process_frame when frame is complete' do
            EM.add_timer(0.2) {
              @client.should_receive(:process_frame).with(basic_header)
              @client.receive_data(basic_header.to_s[0..5])
              @client.receive_data(basic_header.to_s[6..-1])
              done }
          end
        end #receive_data

        describe '#process_frame', '(client reaction to messages from broker)' do

          it 'delegates frame processing to channel if the frame indicates channel' do
            EM.add_timer(0.2) {
              MQ.new(@client)
              @client.channels[1].should_receive(:process_frame).
                  with(basic_header(:channel => 1))
              @client.process_frame(basic_header(:channel => 1))
              done }
          end

          describe ' Frame::Method', '(Method with args received)' do
            describe 'Protocol::Connection::Start',
                     '(broker initiated start of AMQP connection)' do
              let(:frame) { Frame::Method.new(Protocol::Connection::Start.new) }

              it 'sends back to broker Protocol::Connection::StartOk with details' do
                EM.add_timer(0.2) {
                  @client.should_receive(:send).
                      with(Protocol::Connection::StartOk.new(
                               {:platform => 'Ruby/EventMachine',
                                :product => 'AMQP',
                                :information => 'http://github.com/ruby-amqp/amqp',
                                :version => AMQP::VERSION}, 'AMQPLAIN',
                               {:LOGIN => AMQP.settings[:user],
                                :PASSWORD => AMQP.settings[:pass]}, 'en_US'))
                  @client.process_frame(frame)
                  done }
              end
            end # Protocol::Connection::Start

            describe 'Protocol::Connection::Tune',
                     '(broker suggested connection parameters)' do
              let(:frame) { Frame::Method.new(Protocol::Connection::Tune.new) }

              it 'sends back to broker TuneOk with parameters and Open' do
                EM.add_timer(0.2) {
                  @client.should_receive(:send) do |method|
                    if method.is_a? Protocol::Connection::TuneOk
                      method.should == Protocol::Connection::TuneOk.new(
                          :channel_max => 0,
                          :frame_max => 131072,
                          :heartbeat => 0)
                    else
                      method.should == Protocol::Connection::Open.new(
                          :virtual_host => AMQP.settings[:vhost],
                          :capabilities => '',
                          :insist => AMQP.settings[:insist])
                    end
                  end.exactly(2).times
                  @client.process_frame(frame)
                  done }
              end
            end # Protocol::Connection::Tune

            describe 'Protocol::Connection::OpenOk',
                     '(broker confirmed connection opening)' do
              let(:frame) { Frame::Method.new(AMQP::Protocol::Connection::OpenOk.new) }

              it 'succeeds @client (as a deferrable)' do
                @client.instance_variable_get(:@deferred_status).should == :unknown
                @client.process_frame(frame)
                done(0.1) {
                  @client.instance_variable_get(:@deferred_status).should == :succeeded }
              end
            end # Protocol::Connection::OpenOk

            describe 'Protocol::Connection::Close',
                     '(unexpectedly received connection close from broker)' do
              let(:frame) { Frame::Method.new(Protocol::Connection::Close.new(
                                                  :reply_code => 320,
                                                  :reply_text => "Nyanya",
                                                  :class_id => 10,
                                                  :method_id => 40)) }

              it 'just prints debug info to STDERR' do
                STDERR.should_receive(:puts).
                    with /Nyanya in AMQP::Protocol::Connection::Open/
                @client.process_frame(frame)
                done(0.1)
              end

              it 'should probably raise exception or something?'
            end # Protocol::Connection::Close

            describe 'Protocol::Connection::CloseOk',
                     '(broker confirmed our connection close request)' do
              let(:frame) { Frame::Method.new(Protocol::Connection::CloseOk.new) }

              it 'calls registered @on_disconnect hook' do
                EM.add_timer(0.1) {
                  subject_mock(:@on_disconnect).should_receive(:call).with(no_args)
                  @client.process_frame(frame)
                  done }
              end

            end # Protocol::Connection::CloseOk
          end # Frame::Method
        end #process_frame
      end # receiving data/processing frames

      context 'channels' do
        it 'starts with empty channels set' do
          @client.channels.should be_empty
          done
        end

        context '#add_channel' do
          it 'adds given channel to channels set' do
            mq = mock('mq')
            @client.add_channel mq
            @client.channels[1].should == mq
            done
          end
        end
      end

      context '#send data' do
        it 'formats data to be sent into Frame, setting channel to 0 by default' do
          data = mock('data')
          framed_data = mock('framed data')
          data.should_receive(:to_frame).and_return(framed_data)
          framed_data.should_receive(:channel=).with(0)
          @client.send data
          done
        end

        it 'sets channel number given in options' do
          data = mock('data')
          framed_data = mock('framed data')
          data.should_receive(:to_frame).and_return(framed_data)
          framed_data.should_receive(:channel=).with(1313)
          @client.send data, :channel =>1313
          done
        end

        it 'does not format data if it is already a Frame' do
          data = basic_header
          data.should_not_receive(:to_frame)
          @client.send data
          done
        end

        it 'then calls EM:Connection#send_data hook with framed data converted to String' do
          EM.add_timer(0.1) {
            data = basic_header
            @client.should_receive(:send_data) do |data|
              data.should be_a String
              frame = Frame.parse(data)
              frame.class.should == Frame::Header
              frame.payload.class.should == Protocol::Header
              frame.channel.should == 0
            end
            @client.send data
            done }
        end
      end #send data

      context '#connection_status' do
        em_before { @called_with_statuses = [] }
        it 'sets a block to be called on connection status changes' do
          @client.connection_status { |status| @called_with_statuses << status }
          @client.close
          done(0.1) { @called_with_statuses.should == [:connected, :disconnected] }
        end

      end #connection_status
    end #given a connected client
  end # context with AMQP.client set to BasicClient (default)
end
