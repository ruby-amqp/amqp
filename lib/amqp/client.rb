# encoding: utf-8

module AMQP
  # @api public
  def self.client
    # TODO
  end

  # def self.client=(value)
  # end



  module Client
    # @api public
    def self.connect(arg = nil)

    end


    # @api public
    def initialize(options = {})
      # TODO
    end # initialize(options = {})


    # @api public
    def tcp_connection_established?
      # TODO
    end

    # @api public
    def connected?
      # TODO
    end

    # @api public
    def channels
      # TODO
    end # channels

    # @api public
    def send(data, options = {})
      # TODO
    end # send(data, options = {})

    # @api public
    def closing?
      # TODO
    end # closing?

    # @api public
    def reconnect(force = false)
      # TODO
    end # reconnect(force = false)
  end # Client
end # AMQP
