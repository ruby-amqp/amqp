# encoding: utf-8

require "amq/client/openable"
require "amq/client/async/callbacks"

module AMQ
  module Client
    module Async
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
          AMQ::Client::HandlersRegistry.register(klass, &block)
        end

        def handlers
          AMQ::Client::HandlersRegistry.handlers
        end
      end # ProtocolMethodHandlers


      # AMQ entities, as implemented by AMQ::Client, have callbacks and can run them
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
        include Async::Callbacks

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
    end # Async
  end # Client
end # AMQ
