# encoding: utf-8

require "uri"
require "amqp/session"

module AMQP
  # @private
  module Client

    # @private
    AMQP_PORTS = Hash["amqp" => 5672, "amqps" => 5671].freeze
    # @private
    AMQPS      = "amqps".freeze


    # {AMQP.connect} delegates to this method. There is no reason for applications or
    # libraries to use this method directly.
    #
    #
    # @note This method is not part of the public API and may be removed in the future without any warning.
    # @see AMQP.start
    # @see AMQP.connect
    # @api plugin
    #
    # @see http://bit.ly/ks8MXK Connecting to The Broker documentation guide
    def self.connect(connection_string_or_options = {}, options = {}, &block)
      opts = case connection_string_or_options
             when String then
               parse_connection_uri(connection_string_or_options)
             when Hash then
               connection_string_or_options
             else
               Hash.new
             end

      if block
        AMQP.client.connect(opts.merge(options), &block)
      else
        AMQP.client.connect(opts.merge(options))
      end
    end

    # Parses AMQP connection string and returns it's components as a hash.
    #
    # h2. vhost naming schemes
    #
    # AMQP 0.9.1 spec does not define what vhost naming scheme should be. RabbitMQ and Apache Qpid use different schemes
    # (Qpid said to have two) but the bottom line is: even though some brokers use / as the default vhost, it can be *any string*.
    # Host (and optional port) part must be separated from vhost (path component) with a slash character (/).
    #
    # This method will also unescape path part of the URI.
    #
    # @example How vhost is parsed
    #
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com")            # => vhost is nil, so default (/) will be used
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/")           # => vhost is an empty string
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com//")          # => vhost is /
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com//vault")     # => vhost is /vault
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/%2Fvault")   # => vhost is /vault
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/production") # => vhost is production
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com/a.b.c")      # => vhost is a.b.c
    #   AMQP::Client.parse_connection_uri("amqp://dev.rabbitmq.com///a/b/c/d")  # => vhost is //a/b/c/d
    #
    #
    # @param [String] connection_string AMQP connection URI, à la JDBC connection string. For example: amqp://bus.megacorp.internal:5877.
    # @return [Hash] Connection parameters (:username, :password, :vhost, :host, :port, :ssl)
    #
    # @raise [ArgumentError] When connection URI schema is not amqp or amqps.
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
      opts[:vhost]  = URI.unescape($1) if uri.path =~ %r{^/(.*)}
      opts[:host]   = uri.host if uri.host
      opts[:port]   = uri.port || AMQP_PORTS[uri.scheme]
      opts[:ssl]    = uri.scheme == AMQPS

      opts
    end
  end # Client



  # @private
  def self.client
    @client_implementation ||= AMQP::Session
  end

  # @private
  def self.client=(value)
    @client_implementation = value
  end
end # AMQP
