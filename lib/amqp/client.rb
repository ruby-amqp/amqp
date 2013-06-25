# encoding: utf-8

require 'amq/client/settings'
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
    # @see http://rubyamqp.info/articles/connecting_to_broker/ Connecting to The Broker documentation guide
    def self.connect(connection_string_or_options = {}, options = {}, &block)
      opts = case connection_string_or_options
             when String then
               parse_connection_uri(connection_string_or_options)
             when Hash then
               connection_string_or_options
             else
               Hash.new
             end

      connection = if block
                     AMQP.client.connect(opts.merge(options), &block)
                   else
                     AMQP.client.connect(opts.merge(options))
                   end

      connection
    end

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
    # @see http://rubyamqp.info/articles/connecting_to_broker/ Connecting to The Broker documentation guide
    # @api public
    def self.parse_connection_uri(connection_string)
      AMQ::Client::Settings.parse_amqp_url(connection_string)
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
