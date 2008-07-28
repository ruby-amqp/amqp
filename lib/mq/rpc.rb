class MQ
  class RPC < BlankSlate
    def initialize mq, queue, obj = nil
      @mq = mq
      @mq.rpcs[queue] ||= self

      if obj
        @obj = case obj
               when ::Class
                 obj.new
               when ::Module
                 (::Class.new do include(obj) end).new
               else
                 obj
               end
        
        @mq.queue(queue).subscribe{ |info, request|
          method, *args = ::Marshal.load(request)
          ret = @obj.__send__(method, *args)

          if info.reply_to
            @mq.queue(info.reply_to).publish(::Marshal.dump(ret), :key => info.reply_to, :message_id => info.message_id)
          end
        }
      else
        @callbacks ||= {}
        @queue = @mq.queue(@name = 'some random identifier for me').subscribe{|info, msg|
          if blk = @callbacks.delete(info.message_id)
            blk.call ::Marshal.load(msg)
          end
        }
        @remote = @mq.queue(queue)
      end
    end

    def method_missing meth, *args, &blk
      message_id = "random message id #{::Kernel.rand(999_999_999_999)}"
      @callbacks[message_id] = blk if blk
      @remote.publish(::Marshal.dump([meth, *args]), :reply_to => blk ? @name : nil, :message_id => message_id)
    end
  end
end