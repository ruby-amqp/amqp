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

    def initialize(opts = {})
      @settings = opts
      extend AMQP.client

      @_channel_mutex = Mutex.new

      @on_disconnect ||= proc { raise Error, "Could not connect to server #{opts[:host]}:#{opts[:port]}" }

      timeout @settings[:timeout] if @settings[:timeout]
      errback { @on_disconnect.call } unless @reconnecting

      # TCP connection "openness"
      @tcp_connection_established = false
      # AMQP connection "openness"
      @connected                  = false
    end

    def connection_completed
      start_tls if @settings[:ssl]
      log 'connected'
      # @on_disconnect = proc { raise Error, 'Disconnected from server' }
      unless @closing
        @reconnecting = false
      end

      @tcp_connection_established = true

      @buf = Buffer.new
      send_data HEADER
      send_data [1, 1, VERSION_MAJOR, VERSION_MINOR].pack('C4')
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

    def self.connect amqp_url_or_opts = nil
      if amqp_url_or_opts.is_a?(String)
        opts = parse_amqp_url(amqp_url_or_opts)
      elsif amqp_url_or_opts.is_a?(Hash)
        opts = amqp_url_or_opts
      elsif amqp_url_or_opts.nil?
        opts = Hash.new
      end

      opts = AMQP.settings.merge(opts)
      EM.connect opts[:host], opts[:port], self, opts
    end

    def connection_status(&blk)
      @connection_status = blk
    end

    private

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

    def self.parse_amqp_url(amqp_url)
      uri = URI.parse(amqp_url)
      raise("amqp:// uri required!") unless %w{amqp amqps}.include? uri.scheme
      opts = {}
      opts[:user] = URI.unescape(uri.user) if uri.user
      opts[:pass] = URI.unescape(uri.password) if uri.password
      opts[:vhost] = URI.unescape(uri.path) if uri.path
      opts[:host] = uri.host if uri.host
      opts[:port] = uri.port ? uri.port :
                      {"amqp" => 5672, "amqps" => 5671}[uri.scheme]
      opts[:ssl] = uri.scheme == "amqps"
      return opts
    end
  end
end
