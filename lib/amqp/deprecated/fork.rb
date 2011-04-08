require "amqp/ext/em"

module AMQP
  # @deprecated
  # @api public
  def self.fork(workers)
    EM.fork(workers) do
      # clean up globals in the fork
      Thread.current[:mq] = nil
      AMQP.instance_variable_set('@conn', nil)

      yield
    end
  end  
end