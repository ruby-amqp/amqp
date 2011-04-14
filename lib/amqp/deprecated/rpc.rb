# encoding: utf-8

module AMQP
  if defined?(BasicObject)
    # @private
    class BlankSlate < BasicObject; end
  else
    # @private
    class BlankSlate
      instance_methods.each { |m| undef_method m unless m =~ /^__/ }
    end
  end


  # Basic RPC (remote procedure call) facility.
  #
  # Needs more detail and explanation.
  #
  #  EM.run do
  #    server = AMQP::Channel.new.rpc('hash table node', Hash)
  #
  #    client = AMQP::Channel.new.rpc('hash table node')
  #    client[:now] = Time.now
  #    client[:one] = 1
  #
  #    client.values do |res|
  #      p 'client', :values => res
  #    end
  #
  #    client.keys do |res|
  #      p 'client', :keys => res
  #      EM.stop_event_loop
  #    end
  #  end
  #
  #
  # @note This class will be removed before 1.0 release.
  # @deprecated
  class RPC < ::AMQP::BlankSlate

    #
    # API
    #


    attr_reader :name

    # Takes a channel, queue and optional object.
    #
    # The optional object may be a class name, module name or object
    # instance. When given a class or module name, the object is instantiated
    # during this setup. The passed queue is automatically subscribed to so
    # it passes all messages (and their arguments) to the object.
    #
    # Marshalling and unmarshalling the objects is handled internally. This
    # marshalling is subject to the same restrictions as defined in the
    # {http://ruby-doc.org/core/classes/Marshal.html Marshal} standard
    # library. See that documentation for further reference.
    #
    # When the optional object is not passed, the returned rpc reference is
    # used to send messages and arguments to the queue. See #method_missing
    # which does all of the heavy lifting with the proxy. Some client
    # elsewhere must call this method *with* the optional block so that
    # there is a valid destination. Failure to do so will just enqueue
    # marshalled messages that are never consumed.
    #
    def initialize(channel, queue, obj = nil)
      @name    = queue
      @channel = channel
      @channel.register_rpc(self)

      if @obj = normalize(obj)
        @delegate = Server.new(channel, queue, @obj)
      else
        @delegate = Client.new(channel, queue)
      end
    end


    def client?
      @obj.nil?
    end

    def server?
      !client?
    end


    def method_missing(selector, *args, &block)
      @delegate.__send__(selector, *args, &block)
    end


    # @private
    class Client
      attr_accessor :identifier

      def initialize(channel, server_queue_name)
        @channel           = channel
        @exchange          = AMQP::Exchange.default(@channel)
        @server_queue_name = server_queue_name

        @handlers          = Hash.new
        @queue             = channel.queue("__amqp_gem_rpc_client_#{rand(1_000_000)}", :auto_delete => true)

        @queue.subscribe do |header, payload|
          *response_args = Marshal.load(payload)
          handler        = @handlers[header.message_id]

          handler.call(*response_args)
        end
      end

      def method_missing(selector, *args, &block)
        @channel.once_open do
          message_id   = "message_identifier_#{rand(1_000_000)}"

          if block
            @handlers[message_id] = block
            @exchange.publish(Marshal.dump([selector, *args]), :routing_key => @server_queue_name, :reply_to => @queue.name, :message_id => message_id)
          else
            @exchange.publish(Marshal.dump([selector, *args]), :routing_key => @server_queue_name, :message_id => message_id)
          end
        end
      end
    end # Client

    # @private
    class Server
      def initialize(channel, queue_name, impl)
        @channel  = channel
        @exchange = AMQP::Exchange.default(@channel)
        @queue    = @channel.queue(queue_name)
        @impl     = impl

        @handlers     = Hash.new
        @id           = "client_identifier_#{rand(1_000_000)}"

        @queue.subscribe(:ack => true) do |header, payload|
          selector, *args = Marshal.load(payload)
          result = @impl.__send__(selector, *args)

          respond_to(header, result) if header.to_hash[:reply_to]
          header.ack
        end
      end

      def respond_to(header, result)
        @exchange.publish(Marshal.dump(result), :message_id => header.message_id, :routing_key => header.reply_to)
      end
    end # Server



    protected

    def normalize(input)
      case input
      when ::Class
        input.new
      when ::Module
        (::Class.new do include(obj) end).new
      else
        input
      end
    end
  end # RPC
end # AMQP
