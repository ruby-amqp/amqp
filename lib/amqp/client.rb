# encoding: utf-8

require "amqp/basic_client"

require 'uri'

module AMQP
  def self.client
    @client ||= BasicClient
  end

  def self.client= mod
    mod.__send__ :include, AMQP
    @client = mod
  end

  module Client
    include EM::Deferrable

    #
    # API
    #

    attr_reader :settings

    def initialize(opts = {})
      @settings = opts
      extend AMQP.client

      @_channel_mutex = Mutex.new

      @on_disconnect ||= proc { raise Error, "Could not connect to server #{opts[:host]}:#{opts[:port]}" }

      timeout @settings[:timeout] if @settings[:timeout]
      errback { @on_disconnect.call } unless @reconnecting
      @connection_status = @settings[:connection_status]

      # TCP connection "openness"
      @tcp_connection_established = false
      # AMQP connection "openness"
      @connected                  = false
    end

    def connection_completed
      if @settings[:ssl].is_a? Hash
        start_tls @settings[:ssl]
      elsif @settings[:ssl]
        start_tls
      end

      log 'connected'
      # @on_disconnect = proc { raise Error, 'Disconnected from server' }
      unless @closing
        @reconnecting = false
      end

      @tcp_connection_established = true

      @buf = Buffer.new
      send_data HEADER
      send_data [1, 1, VERSION_MAJOR, VERSION_MINOR].pack('C4')

      if heartbeat = @settings[:heartbeat]
        init_heartbeat if (@settings[:heartbeat] = heartbeat.to_i) > 0
      end
    end

    def init_heartbeat
      @last_server_heartbeat = Time.now

      @timer.cancel if @timer
      @timer = EM::PeriodicTimer.new(@settings[:heartbeat]) do
        if connected?
          if @last_server_heartbeat < (Time.now - (@settings[:heartbeat] * 2))
            log "Reconnecting due to missing server heartbeats"
            reconnect(true)
          else
            @last_server_heartbeat = Time.now
            send AMQP::Frame::Heartbeat.new, :channel => 0
          end
        end
      end
    end

    def tcp_connection_established?
      @tcp_connection_established
    end # tcp_connection_established?

    def connected?
      @connected
    end

    def unbind
      log 'disconnected'
      @connected = false
      EM.next_tick { @on_disconnect.call; @tcp_connection_established = false }
    end

    def add_channel(mq)
      @_channel_mutex.synchronize do
        channels[ key = (channels.keys.max || 0) + 1 ] = mq
        key
      end
    end

    def channels
      @channels ||= {}
    end

    def receive_data(data)
      # log 'receive_data', data
      @buf << data

      while frame = Frame.parse(@buf)
        log 'receive', frame
        process_frame frame
      end
    end

    def process_frame(frame)
      # this is a stub meant to be
      # replaced by the module passed into initialize
    end

    def send(data, opts = {})
      channel = opts[:channel] ||= 0
      data = data.to_frame(channel) unless data.is_a? Frame
      data.channel = channel

      log 'send', data
      send_data data.to_s
    end

    #:stopdoc:
    # def send_data data
    #   log 'send_data', data
    #   super
    # end
    #:startdoc:

    def close(&on_disconnect)
      if on_disconnect
        @closing = true
        @on_disconnect = proc {
          on_disconnect.call
          @closing = false
        }
      end

      callback { |c|
        if c.channels.any?
          c.channels.each do |ch, mq|
            mq.close
          end
        else
          send Protocol::Connection::Close.new(:reply_code => 200,
                                               :reply_text => 'Goodbye',
                                               :class_id => 0,
                                               :method_id => 0)
        end
      }
    end

    def closing?
      @closing
    end

    def reconnect(force = false)
      if @reconnecting and not force
        # wait 1 second after first reconnect attempt, in between each subsequent attempt
        EM.add_timer(1) { reconnect(true) }
        return
      end

      unless @reconnecting
        @reconnecting = true

        @deferred_status = nil
        initialize(@settings)

        mqs = @channels
        @channels = {}
        mqs.each { |_, mq| mq.reset } if mqs
      end

      log 'reconnecting'
      EM.reconnect @settings[:host], @settings[:port], self
    end

    def self.connect(arg = nil)
      opts = case arg
             when String then
               opts = parse_connection_uri(arg)
             when Hash then
               arg
             else
               Hash.new
             end

      options = AMQP.settings.merge(opts)

      if options[:username]
        options[:user] = options.delete(:username)
      end

      if options[:password]
        options[:pass] = options.delete(:password)
      end

      EM.connect options[:host], options[:port], self, options
    end

    def connection_status(&blk)
      @connection_status = blk
    end

    private

    def self.parse_connection_uri(connection_string)
      uri = URI.parse(connection_string)
      raise("amqp:// uri required!") unless %w{amqp amqps}.include?(uri.scheme)

      opts = {}

      opts[:user]  = URI.unescape(uri.user) if uri.user
      opts[:pass]  = URI.unescape(uri.password) if uri.password
      opts[:vhost] = URI.unescape(uri.path) if uri.path
      opts[:host]  = uri.host if uri.host
      opts[:port]  = uri.port || Hash["amqp" => 5672, "amqps" => 5671][uri.scheme]
      opts[:ssl]   = uri.scheme == "amqps"

      opts
    end


    def disconnected
      @connection_status.call(:disconnected) if @connection_status
      reconnect
    end

    def log(*args)
      return unless @settings[:logging] or AMQP.logging
      require 'pp'
      pp args
      puts
    end
  end
end
