# Alias for AMQP::Channel.
#
# @note This class will be removed before 1.0 release.
# @deprecated
class MQ < AMQP::Channel; end


class MQ
  # Alias for AMQP::Exchange.
  #
  # @note This class will be removed before 1.0 release.
  # @deprecated
  class Exchange < ::AMQP::Exchange; end

  # Alias for AMQP::Queue.
  #
  # @note This class will be removed before 1.0 release.
  # @deprecated
  class Queue < ::AMQP::Queue; end


  #
  # Backwards compatibility with 0.6.x
  #

  # unique identifier
  def MQ.id
    Thread.current[:mq_id] ||= "#{`hostname`.strip}-#{Process.pid}-#{Thread.current.object_id}"
  end

  # @private
  def MQ.default
    # TODO: clear this when connection is closed
    Thread.current[:mq] ||= MQ.new
  end

  # Allows for calls to all MQ instance methods. This implicitly calls
  # MQ.new so that a new channel is allocated for subsequent operations.
  def MQ.method_missing(meth, *args, &blk)
    MQ.default.__send__(meth, *args, &blk)
  end
end
