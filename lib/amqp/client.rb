# encoding: utf-8

module AMQP
  class BasicClient < AMQ::Client::EventMachineClient

    #
    # API
    #

    # @api public
    def connected?
      self.opened?
    end

    # @api public
    def reconnect(force = false)
      # TODO
      raise NotImplementedError.new
    end # reconnect(force = false)
  end


  # @api public
  def self.client
    @client_implementation ||= BasicClient
  end

  def self.client=(value)
    @client_implementation = value
  end



  module Client
    # @api public
    def self.connect(arg = nil, &block)
      opts = case arg
             when String then
               opts = parse_connection_uri(arg)
             when Hash then
               arg
             else
               Hash.new
             end

      # TODO: maybe wrap client into a bridge-like object
      #       (but only if this backwards-compatibility move is actually worth it)

      if block
        AMQP.client.connect(opts, &block)
      else
        AMQP.client.connect(opts)
      end
    end

    AMQP_PORTS = Hash["amqp" => 5672, "amqps" => 5671].freeze
    AMQPS      = "amqps".freeze


    private

    def self.parse_connection_uri(connection_string)
      uri = URI.parse(connection_string)
      raise("amqp:// uri required!") unless %w{amqp amqps}.include?(uri.scheme)

      opts = {}

      opts[:user]  = URI.unescape(uri.user) if uri.user
      opts[:pass]  = URI.unescape(uri.password) if uri.password
      opts[:vhost] = URI.unescape(uri.path) if uri.path
      opts[:host]  = uri.host if uri.host
      opts[:port]  = uri.port || AMQP_PORTS[uri.scheme]
      opts[:ssl]   = uri.scheme == AMQPS

      opts
    end

  end # Client
end # AMQP
