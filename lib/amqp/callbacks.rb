module AMQP
  module Callbacks

    def redefine_callback(event, callable = nil, &block)
      f = (callable || block)
      # yes, re-assign!
      @callbacks[event] = [f]

      self
    end

    def define_callback(event, callable = nil, &block)
      f = (callable || block)

      @callbacks[event] ||= []
      @callbacks[event] << f if f

      self
    end # define_callback(event, &block)
    alias append_callback define_callback

    def prepend_callback(event, &block)
      @callbacks[event] ||= []
      @callbacks[event].unshift(block)

      self
    end # prepend_callback(event, &block)

    def clear_callbacks(event)
      @callbacks[event].clear if @callbacks[event]
    end # clear_callbacks(event)


    def exec_callback(name, *args, &block)
      list = Array(@callbacks[name])
      if list.any?
        list.each { |c| c.call(*args, &block) }
      end
    end

    def exec_callback_once(name, *args, &block)
      list = (@callbacks.delete(name) || Array.new)
      if list.any?
        list.each { |c| c.call(*args, &block) }
      end
    end

    def exec_callback_yielding_self(name, *args, &block)
      list = Array(@callbacks[name])
      if list.any?
        list.each { |c| c.call(self, *args, &block) }
      end
    end

    def exec_callback_once_yielding_self(name, *args, &block)
      list = (@callbacks.delete(name) || Array.new)

      if list.any?
        list.each { |c| c.call(self, *args, &block) }
      end
    end

    def has_callback?(name)
      @callbacks[name] && !@callbacks[name].empty?
    end # has_callback?
  end # Callbacks
end
