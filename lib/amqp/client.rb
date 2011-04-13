# encoding: utf-8

require "amqp/basic_client"

module AMQP
  module Client

    AMQP_PORTS = Hash["amqp" => 5672, "amqps" => 5671].freeze
    AMQPS      = "amqps".freeze


    # {AMQP.connect} delegates to this method. There is no reason for applications or
    # libraries to use this method directly.
    #
    #
    # @note This method is not part of the public API and may be removed in the future without any warning.
    # @see AMQP.start
    # @see AMQP.connect
    # @api plugin
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
    # @param [String] connection_string AMQP connection URI, à la JDBC connection string. For example: amqp://bus.megacorp.internal:5877/qa
    # @return [Hash] Connection parameters (:username, :password, :vhost, :host, :port, :ssl)
    # @api public
    def self.parse_connection_uri(connection_string)
      uri = URI.parse(connection_string)
      raise("Connection URI must use amqp or amqps schema (example: amqp://bus.megacorp.internal:5766/testbed)") unless %w{amqp amqps}.include?(uri.scheme)

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



  # @private
  def self.client
    @client_implementation ||= BasicClient
  end

  # @private
  def self.client=(value)
    @client_implementation = value
  end

end # AMQP
