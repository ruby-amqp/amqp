# encoding: utf-8

require File.expand_path('../frame', __FILE__)

require 'uri'

module AMQP
  class Error < StandardError; end

  module BasicClient
    def process_frame(frame)
      if mq = channels[frame.channel]
        mq.process_frame(frame)
        return
      end

      case frame
      when Frame::Method
        case method = frame.payload
        when Protocol::Connection::Start
          send Protocol::Connection::StartOk.new({:platform => 'Ruby/EventMachine',
                                                  :product => 'AMQP',
                                                  :information => 'http://github.com/ruby-amqp/amqp',
                                                  :version => VERSION},
                                                 'AMQPLAIN',
                                                 {:LOGIN => @settings[:user],
                                                  :PASSWORD => @settings[:pass]},
                                                 'en_US')

        when Protocol::Connection::Tune
          send Protocol::Connection::TuneOk.new(:channel_max => 0,
                                                :frame_max => 131072,
                                                :heartbeat => 0)

          send Protocol::Connection::Open.new(:virtual_host => @settings[:vhost],
                                              :capabilities => '',
                                              :insist => @settings[:insist])

        when Protocol::Connection::OpenOk
          succeed(self)

        when Protocol::Connection::Close
          # raise Error, "#{method.reply_text} in #{Protocol.classes[method.class_id].methods[method.method_id]}"
          STDERR.puts "#{method.reply_text} in #{Protocol.classes[method.class_id].methods[method.method_id]}"

        when Protocol::Connection::CloseOk
          @on_disconnect.call if @on_disconnect
        end
      end
    end
  end

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

      @on_disconnect ||= proc { raise Error, "Could not connect to server #{opts[:host]}:#{opts[:port]}" }

      timeout @settings[:timeout] if @settings[:timeout]
      errback { @on_disconnect.call } unless @reconnecting

      @connected = false
    end

    def connection_completed
      start_tls if @settings[:ssl]
      log 'connected'
      # @on_disconnect = proc { raise Error, 'Disconnected from server' }
      unless @closing
        @on_disconnect = method(:disconnected)
        @reconnecting = false
      end

      @connected = true
      @connection_status.call(:connected) if @connection_status

      @buf = Buffer.new
      send_data HEADER
      send_data [1, 1, VERSION_MAJOR, VERSION_MINOR].pack('C4')
    end

    def connected?
      @connected
    end

    def unbind
      log 'disconnected'
      @connected = false
      EM.next_tick { @on_disconnect.call }
    end

    def add_channel(mq)
      (@_channel_mutex ||= Mutex.new).synchronize do
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
