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

  def self.mutex
    @mutex ||= Mutex.new
  end

  def self.channel
    self.mutex.synchronize { @channel }
  end

  def self.channel=(value)
    self.mutex.synchronize { @channel = value }
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
      EM.next_tick {
        @on_disconnect.call if @on_disconnect
        @tcp_connection_established = false
      }
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

    AMQP_PORTS = Hash["amqp" => 5672, "amqps" => 5671].freeze

    # Parses AMQP connection URI and returns its components as a hash.
    #
    # h2. vhost naming schemes
    #
    # It is convenient to be able to specify the AMQP connection
    # parameters as a URI string, and various "amqp" URI schemes
    # exist.  Unfortunately, there is no standard for these URIs, so
    # while the schemes share the basic idea, they differ in some
    # details.  This implementation aims to encourage URIs that work
    # as widely as possible.
    #
    # The URI scheme should be "amqp", or "amqps" if SSL is required.
    #
    # The host, port, username and password are represented in the
    # authority component of the URI in the same way as in http URIs.
    #
    # The vhost is obtained from the first segment of the path, with the
    # leading slash removed.  The path should contain only a single
    # segment (i.e, the only slash in it should be the leading one).
    # If the vhost is to include slashes or other reserved URI
    # characters, these should be percent-escaped.
    #
    # @example How vhost is parsed
    #
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com")            # => vhost is nil, so default (/) will be used
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/")           # => vhost is an empty string
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/%2Fvault")   # => vhost is /vault
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/production") # => vhost is production
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/a.b.c")      # => vhost is a.b.c
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/foo/bar")    # => ArgumentError
    #
    #
    # @param [String] connection_string AMQP connection URI, à la JDBC connection string. For example: amqp://bus.megacorp.internal:5877.
    # @return [Hash] Connection parameters (:username, :password, :vhost, :host, :port, :ssl)
    #
    # @raise [ArgumentError] When connection URI schema is not amqp or amqps, or the path contains multiple segments
    #
    # @see http://bit.ly/ks8MXK Connecting to The Broker documentation guide
    # @api public
    def self.parse_connection_uri(connection_string)
      uri = URI.parse(connection_string)
      raise ArgumentError.new("Connection URI must use amqp or amqps schema (example: amqp://bus.megacorp.internal:5766), learn more at http://bit.ly/ks8MXK") unless %w{amqp amqps}.include?(uri.scheme)

      opts = {}

      opts[:scheme] = uri.scheme
      opts[:user]   = URI.unescape(uri.user) if uri.user
      opts[:pass]   = URI.unescape(uri.password) if uri.password
      opts[:host]   = uri.host if uri.host
      opts[:port]   = uri.port || AMQP_PORTS[uri.scheme]
      opts[:ssl]    = uri.scheme == "amqps"
      if uri.path =~ %r{^/(.*)}
        raise ArgumentError.new("#{uri} has multiple-segment path; please percent-encode any slashes in the vhost name (e.g. /production => %2Fproduction). Learn more at http://bit.ly/amqp-gem-and-connection-uris") if $1.index('/')
        opts[:vhost] = URI.unescape($1)
      end

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
