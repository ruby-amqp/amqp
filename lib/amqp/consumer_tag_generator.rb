module AMQP
  class ConsumerTagGenerator

    #
    # API
    #

    # @return [String] Generated consumer tag
    def generate
      "#{Kernel.rand}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
    end # generate

    # @return [String] Generated consumer tag
    def generate_for(queue)
      raise ArgumentError, "argument must respond to :name" unless queue.respond_to?(:name)

      "#{queue.name}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
    end # generate_for(queue)
  end # ConsumerTagGenerator
end
