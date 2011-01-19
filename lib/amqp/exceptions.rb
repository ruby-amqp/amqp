module AMQP
  class Error < StandardError; end
end # AMQP

module AMQP
  # Raised whenever an illegal operation is attempted.
  class Error < StandardError; end

  class IncompatibleOptionsError < Error
    def initialize(name, opts_1, opts_2)
      super("There is already an instance called #{name} with options #{opts_1.inspect}, you can't define the same instance with different options (#{opts_2.inspect})!")
    end
  end # IncompatibleOptionsError

  class ChannelClosedError < Error
    def initialize(instance)
      super("The channel #{instance.channel} was closed, you can't use it anymore!")
    end
  end # ChannelClosedError
end # MQ
