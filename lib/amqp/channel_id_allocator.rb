module AMQP
  module ChannelIdAllocator

    MAX_CHANNELS_PER_CONNECTION = (2**16) - 1

    # Resets channel allocator. This method is thread safe.
    # @api public
    # @see Channel.next_channel_id
    # @see Channel.release_channel_id
    def reset_channel_id_allocator
      channel_id_mutex.synchronize do
        int_allocator.reset
      end
    end

    # Releases previously allocated channel id. This method is thread safe.
    #
    # @param [Fixnum] Channel id to release
    # @api public
    # @see Channel.next_channel_id
    # @see Channel.reset_channel_id_allocator
    def release_channel_id(i)
      channel_id_mutex.synchronize do
        int_allocator.release(i)
      end
    end

    # Returns next available channel id. This method is thread safe.
    #
    # @return [Fixnum]
    # @api public
    # @see Channel.release_channel_id
    # @see Channel.reset_channel_id_allocator
    def next_channel_id
      channel_id_mutex.synchronize do
        result = int_allocator.allocate
        raise "No further channels available. Please open a new connection." if result < 0
        result
      end
    end

    private

    # @private
    # @api private
    def channel_id_mutex
      @channel_id_mutex ||= Mutex.new
    end

    # @private
    def int_allocator
      # TODO: ideally, this should be in agreement with agreed max number of channels of the connection,
      #       but it is possible that value either not yet available. MK.
      @int_allocator ||= IntAllocator.new(1, MAX_CHANNELS_PER_CONNECTION)
    end

  end
end
