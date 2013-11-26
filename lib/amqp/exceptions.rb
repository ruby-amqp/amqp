# encoding: utf-8

module AMQP
  # Base class for AMQP connection lifecycle exceptions.
  # @api public
  class Error < StandardError
    # An exception in one of the underlying libraries that caused this
    # exception to be re-thrown. May be nil.
    attr_reader :cause
  end


  # All the exceptions below are new in 0.8.0. Previous versions
  # used AMQP::Error for everything. We have to carry this baggage but
  # there is a way out: simply subclass AMQP::Error and provide a backwards-compatible
  # way of attaching root cause exception (like AMQ::Client::TCPConnectionFailed) instance
  # to it.
  #
  # In other words: AMQP::Error is here to stay for a long time. MK.



  # Raised when initial TCP connection to the broker fails.
  # @api public
  class TCPConnectionFailed < Error
    # @return [Hash] connection settings that were used
    attr_reader :settings

    def initialize(settings, cause = nil)
      @settings = settings
      @cause    = cause

      super("Could not establish TCP connection to #{@settings[:host]}:#{@settings[:port]}")
    end # TCPConnectionFailed
  end

  # Raised when authentication fails.
  # @api public
  class PossibleAuthenticationFailureError < Error
    # @return [Hash] connection settings that were used
    attr_reader :settings

    def initialize(settings)
      @settings = settings

      super("AMQP broker closed TCP connection before authentication succeeded: this usually means authentication failure due to misconfiguration. Settings are #{filtered_settings.inspect}")
    end # initialize(settings)

    def filtered_settings
      filtered_settings = settings.dup
      [:pass, :password].each do |sensitve_setting|
        filtered_settings[sensitve_setting] &&= '[filtered]'
      end

      filtered_settings
    end
  end # PossibleAuthenticationFailureError



  # Raised when queue (or exchange) declaration fails because another queue with the same
  # name but different attributes already exists in the channel object cache.
  # @api public
  class IncompatibleOptionsError < Error
    def initialize(name, opts_1, opts_2)
      super("There is already an instance called #{name} with options #{opts_1.inspect}, you can't define the same instance with different options (#{opts_2.inspect})!")
    end
  end # IncompatibleOptionsError

  # Raised on attempt to use a channel that was previously closed
  # (either due to channel-level exception or intentionally via AMQP::Channel#close).
  # @api public
  class ChannelClosedError < Error
    def initialize(instance)
      super("Channel with id = #{instance.channel} is closed, you can't use it anymore!")
    end
  end # ChannelClosedError

  # Raised on attempt to use a connection that was previously closed
  # @api public
  class ConnectionClosedError < Error
    def initialize(frame)
      super("The connection is closed, you can't use it anymore!")
    end
  end # ConnectionClosedError
end # AMQP
