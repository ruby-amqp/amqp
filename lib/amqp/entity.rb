require "amqp/openable"
require "amqp/callbacks"

module AMQP
  module RegisterEntityMixin
    # @example Registering Channel implementation
    #  Adapter.register_entity(:channel, Channel)
    #   # ... so then I can do:
    #  channel = client.channel(1)
    #  # instead of:
    #  channel = Channel.new(client, 1)
    def register_entity(name, klass)
      define_method(name) do |*args, &block|
        klass.new(self, *args, &block)
      end # define_method
    end # register_entity
  end # RegisterEntityMixin

  module ProtocolMethodHandlers
    def handle(klass, &block)
      HandlersRegistry.register(klass, &block)
    end

    def handlers
      HandlersRegistry.handlers
    end
  end # ProtocolMethodHandlers


  # AMQ entities, as implemented by AMQP, have callbacks and can run them
  # when necessary.
  #
  # @note Exchanges and queues implementation is based on this class.
  #
  # @abstract
  module Entity

    #
    # Behaviors
    #

    include Openable
    include Callbacks

    #
    # API
    #

    # @return [Array<#call>]
    attr_reader :callbacks


    def initialize(connection)
      @connection = connection
      # Be careful with default values for #ruby hashes: h = Hash.new(Array.new); h[:key] ||= 1
      # won't assign anything to :key. MK.
      @callbacks  = Hash.new
    end # initialize
  end # Entity

  # Common behavior of AMQ entities that can be either client or server-named, for example, exchanges and queues.
  module ServerNamedEntity

    # @return [Boolean] true if this entity is anonymous (server-named)
    def server_named?
      @server_named || @name.nil? || @name.empty?
    end
    # backwards compabitility. MK.
    alias anonymous? server_named?
  end # ServerNamedEntity
end
