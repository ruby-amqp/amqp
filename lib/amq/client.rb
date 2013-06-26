# encoding: utf-8

require "amq/client/version"
require "amq/client/exceptions"
require "amq/client/handlers_registry"
require "amq/client/adapter"
require "amq/client/channel"
require "amq/client/exchange"
require "amq/client/queue"

begin
  require "amq/protocol/client"
rescue LoadError => exception
  if exception.message.match("amq/protocol")
    raise LoadError.new("amq-client could not load amq-protocol.")
  else
    raise exception
  end
end

module AMQ
  module Client
    # List available adapters as a hash of { :adapter_name => metadata },
    # where metadata are hash with :path and :const_name keys.
    #
    # @return [Hash]
    # @api plugin
    def self.adapters
      @adapters ||= (self.async_adapters)
    end

    # List available asynchronous adapters.
    #
    # @return [Hash]
    # @api plugin
    # @see AMQ::Client.adapters
    def self.async_adapters
      @async_adapters ||= {
        :eventmachine  => {
          :path       => "amq/client/async/adapters/eventmachine",
          :const_name => "Async::EventMachineClient"
        },
        :event_machine => {
          :path       => "amq/client/async/adapters/eventmachine",
          :const_name => "Async::EventMachineClient"
        },
        :coolio        => {
          :path       => "amq/client/async/adapters/coolio",
          :const_name => "Async::CoolioClient"
        }
      }
    end


    # Establishes connection to AMQ broker using given adapter
    # (defaults to the socket adapter) and returns it. The new
    # connection object is yielded to the block if it is given.
    #
    # @example
    #   AMQ::Client.connect(adapter: "socket") do |client|
    #     # Use the client.
    #   end
    # @param [Hash] Connection parameters, including :adapter to use.
    # @api public
    def self.connect(settings = nil, &block)
      adapter  = (settings && settings.delete(:adapter))
      adapter  = load_adapter(adapter)
      adapter.connect(settings, &block)
    end

    # Loads adapter given its name as a Symbol.
    #
    # @raise [InvalidAdapterNameError] When loading attempt failed (LoadError was raised).
    def self.load_adapter(adapter)
      meta = self.adapters[adapter.to_sym]

      require meta[:path]
      eval(meta[:const_name])
    rescue LoadError
      raise InvalidAdapterNameError.new(adapter)
    end
  end # Client
end # AMQ
