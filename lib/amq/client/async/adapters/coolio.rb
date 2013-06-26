# encoding: utf-8

# http://coolio.github.com

require "cool.io"
require "amq/client"
require "amq/client/framing/string/frame"

module AMQ
  module Client
    module Async
      #
      # CoolioClient is a drop-in replacement for EventMachineClient, if you prefer
      # cool.io style.
      #
      class CoolioClient

        #
        # Behaviours
        #

        include AMQ::Client::Async::Adapter


        #
        # API
        #


        #
        # Cool.io socket delegates most of its operations to the parent adapter.
        # Thus, 99.9% of the time you don't need to deal with this class.
        #
        # @api private
        # @private
        class Socket < ::Coolio::TCPSocket
          attr_accessor :adapter

          # Connects to given host/port and sets parent adapter.
          #
          # @param [CoolioClient]
          # @param [String]
          # @param [Fixnum]
          def self.connect(adapter, host, port)
            socket = super(host, port)
            socket.adapter = adapter
            socket
          end

          # Triggers socket_connect callback
          def on_connect
            #puts "On connect"
            adapter.socket_connected
          end

          # Triggers on_read callback
          def on_read(data)
            # puts "Received data"
            # puts_data(data)
            adapter.receive_data(data)
          end

          # Triggers socket_disconnect callback
          def on_close
            adapter.socket_disconnected
          end

          # Triggers tcp_connection_failed callback
          def on_connect_failed
            adapter.tcp_connection_failed
          end

          # Sends raw data through the socket
          #
          # param [String] Binary data
          def send_raw(data)
            # puts "Sending data"
            # puts_data(data)
            write(data)
          end

          protected
          # Debugging routine
          def puts_data(data)
            puts "    As string:     #{data.inspect}"
            puts "    As byte array: #{data.bytes.to_a.inspect}"
          end
        end



        # Cool.io socket for multiplexing et al.
        #
        # @private
        attr_accessor :socket

        # Hash with available callbacks
        attr_accessor :callbacks

        # Creates a socket and attaches it to cool.io default loop.
        #
        # Called from CoolioClient.connect
        #
        # @see AMQ::Client::Adapter::ClassMethods#connect
        # @param [Hash] connection settings
        # @api private
        def establish_connection(settings)
          @settings     = Settings.configure(settings)

          socket = Socket.connect(self, @settings[:host], @settings[:port])
          socket.attach(Cool.io::Loop.default)
          self.socket = socket


          @on_tcp_connection_failure          = @settings[:on_tcp_connection_failure] || Proc.new { |settings|
            raise self.class.tcp_connection_failure_exception_class.new(settings)
          }
          @on_possible_authentication_failure = @settings[:on_possible_authentication_failure] || Proc.new { |settings|
            raise self.class.authentication_failure_exception_class.new(settings)
          }

          @locale            = @settings.fetch(:locale, "en_GB")
          @client_properties = Settings.client_properties.merge(@settings.fetch(:client_properties, Hash.new))

          @auto_recovery     = (!!@settings[:auto_recovery])

          socket
        end

        # Registers on_open callback
        # @see #on_open
        # @api private
        def register_connection_callback(&block)
          self.on_open(&block)
        end

        # Performs basic initialization. Do not use this method directly, use
        # CoolioClient.connect instead
        #
        # @see AMQ::Client::Adapter::ClassMethods#connect
        # @api private
        def initialize
          # Be careful with default values for #ruby hashes: h = Hash.new(Array.new); h[:key] ||= 1
          # won't assign anything to :key. MK.
          @callbacks    = Hash.new

          self.logger   = self.class.logger

          # channel => collected frames. MK.
          @frames            = Hash.new { Array.new }
          @channels          = Hash.new

          @mechanism         = "PLAIN"
        end

        # Sets a callback for successful connection (after we receive open-ok)
        #
        # @api public
        def on_open(&block)
          define_callback :connect, &block
        end
        alias on_connection on_open

        # Sets a callback for disconnection (as in client-side disconnection)
        #
        # @api public
        def on_closed(&block)
          define_callback :disconnect, &block
        end
        alias on_disconnection on_closed

        # Sets a callback for tcp connection failure (as in can't make initial connection)
        def on_tcp_connection_failure(&block)
          define_callback :tcp_connection_failure, &block
        end


        # Called by AMQ::Client::Connection after we receive connection.open-ok.
        #
        # @api private
        def connection_successful
          @authenticating = false
          opened!

          exec_callback_yielding_self(:connect)
        end


        # Called by AMQ::Client::Connection after we receive connection.close-ok.
        #
        # @api private
        def disconnection_successful
          exec_callback_yielding_self(:disconnect)
          close_connection
          closed!
        end



        # Called when socket is connected but before handshake is done
        #
        # @api private
        def socket_connected
          post_init
        end

        # Called after socket is closed
        #
        # @api private
        def socket_disconnected
        end

        alias close disconnect


        self.handle(Protocol::Connection::Start) do |connection, frame|
          connection.handle_start(frame.decode_payload)
        end

        self.handle(Protocol::Connection::Tune) do |connection, frame|
          connection.handle_tune(frame.decode_payload)

          connection.open(connection.vhost)
        end

        self.handle(Protocol::Connection::OpenOk) do |connection, frame|
          connection.handle_open_ok(frame.decode_payload)
        end

        self.handle(Protocol::Connection::Close) do |connection, frame|
          connection.handle_close(frame.decode_payload)
        end

        self.handle(Protocol::Connection::CloseOk) do |connection, frame|
          connection.handle_close_ok(frame.decode_payload)
        end





        # Sends raw data through the socket
        #
        # @param [String] binary data
        # @api private
        def send_raw(data)
          socket.send_raw data
        end


        # The story about the buffering is kinda similar to EventMachine,
        # you keep receiving more than one frame in a single packet.
        #
        # @param [String] chunk with binary data received. It could be one frame,
        #   more than one frame or less than one frame.
        # @api private
        def receive_data(chunk)
          @chunk_buffer << chunk
          while frame = get_next_frame
            receive_frame(AMQ::Client::Framing::String::Frame.decode(frame))
          end
        end

        # Closes the socket.
        #
        # @api private
        def close_connection
          @socket.close
        end

        # Returns class used for tcp connection failures.
        #
        # @api private
        def self.tcp_connection_failure_exception_class
          AMQ::Client::TCPConnectionFailed
        end # self.tcp_connection_failure_exception_class

        def initialize_heartbeat_sender
          # TODO
        end

        def handle_skipped_hearbeats
          # TODO
        end


        protected

        # @api private
        def post_init
          if @had_successfully_connected_before
            @recovered = true

            self.exec_callback_yielding_self(:before_recovery, @settings)

            self.register_connection_callback do
              self.auto_recover
              self.exec_callback_yielding_self(:after_recovery, @settings)
            end
          end

          # now we can set it. MK.
          @had_successfully_connected_before = true
          @reconnecting                      = false
          @handling_skipped_hearbeats        = false

          self.reset
          self.handshake
        end

        # @api private
        def reset
          @chunk_buffer = ""
          @frames       = Array.new
        end
      end # CoolioClient
    end # Async
  end # Client
end # AMQ
