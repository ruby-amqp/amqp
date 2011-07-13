# encoding: utf-8

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
end
