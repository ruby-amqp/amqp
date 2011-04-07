# encoding: utf-8

module AMQP
  if defined?(BasicObject)
    BlankSlate = BasicObject
  else
    class BlankSlate #:nodoc:
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
    # Marshal[http://ruby-doc.org/core/classes/Marshal.html] standard
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
        # server
        @channel.queue(queue).subscribe(:ack => true) do |info, request|
          ::STDOUT.puts "Got a message on the server-side"
          method, *args = ::Marshal.load(request)
          ret           = @obj.__send__(method, *args)

          if info.reply_to
            info.ack
            @channel.queue(info.reply_to, :auto_delete => true).
              publish(::Marshal.dump(ret), :key => info.reply_to, :message_id => info.message_id)
          end
        end
      else
        # client
        @callbacks = ::Hash.new
        # XXX implement and use queue(nil)
        @reply_to = "random identifier #{::Kernel.rand(999_999_999_999)}"

        @queue = @channel.queue(@reply_to, :auto_delete => true).subscribe do |info, msg|
          ::STDOUT.puts "Got a message on the server-side"
          if blk = @callbacks.delete(info.message_id)
            blk.call ::Marshal.load(msg)
          end
        end

        @channel.queue(queue)
        @remote = Exchange.default(@channel)
      end
    end


    def client?
      @obj.nil?
    end

    def server?
      !client?
    end


    # Calling AMQP::Channel.rpc(*args) returns a proxy object without any methods beyond
    # those in Object. All calls to the proxy are handled by #method_missing which
    # works to marshal and unmarshal all method calls and their arguments.
    #
    #  EM.run do
    #    server = AMQP::Channel.new.rpc('hash table node', Hash)
    #    client = AMQP::Channel.new.rpc('hash table node')
    #
    #    # calls #method_missing on #[] which marshals the method name and
    #    # arguments to publish them to the remote
    #    client[:now] = Time.now
    #    ....
    #  end
    #
    def method_missing(meth, *args, &blk)
      ::Kernel.warn [:method_missing, meth, *args, "with#{"out" if blk.nil?} block"]
      # XXX use uuids instead
      message_id = "random message id #{::Kernel.rand(999_999_999_999)}"

      if blk # an invocation
        @callbacks[message_id] = blk
      end

      if blk
        @remote.publish(::Marshal.dump([meth, *args]), :reply_to => @reply_to, :message_id => message_id, :key => @name)
      else
        @remote.publish(::Marshal.dump([meth, *args]), :message_id => message_id, :key => @name)
      end
    end

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
