# encoding: utf-8

require "amqp/bit_set"

module AMQP
  # Simple bitset-based integer allocator, heavily inspired by com.rabbitmq.utility.IntAllocator class
  # in the RabbitMQ Java client.
  #
  # Unlike monotonically incrementing identifier, this allocator is suitable for very long running programs
  # that aggressively allocate and release channels.
  class IntAllocator

    #
    # API
    #

    # @return [Integer] Number of integers in the allocation range
    attr_reader :number_of_bits
    # @return [Integer] Upper boundary of the integer range available for allocation
    attr_reader :hi
    # @return [Integer] Lower boundary of the integer range available for allocation
    attr_reader :lo

    # @param [Integer] lo    Lower boundary of the integer range available for allocation
    # @param [Integer] hi    Upper boundary of the integer range available for allocation
    # @raise [ArgumentError] if upper boundary is not greater than the lower one
    def initialize(lo, hi)
      raise ArgumentError.new "upper boundary must be greater than the lower one (given: hi = #{hi}, lo = #{lo})" unless hi > lo

      @hi = hi
      @lo = lo

      @number_of_bits = hi - lo
      @range          = Range.new(1, @number_of_bits)
      @free_set       = BitSet.new(@number_of_bits)
    end # initialize(hi, lo)

    # Attempts to allocate next available integer. If allocation succeeds, allocated value is returned.
    # Otherwise, nil is returned.
    #
    # Current implementation of this method is O(n), where n is number of bits in the range available for
    # allocation.
    #
    # @return [Integer] Allocated integer if allocation succeeded. nil otherwise.
    def allocate
      if n = find_unallocated_position
        @free_set.set(n)

        n
      else
        -1
      end
    end # allocate

    # Releases previously allocated integer. If integer provided as argument was not previously allocated,
    # this method has no effect.
    #
    # @return [NilClass] nil
    def free(reservation)
      @free_set.unset(reservation)
    end # free(reservation)
    alias release free

    # @return [Boolean] true if provided argument was previously allocated, false otherwise
    def allocated?(reservation)
      @free_set.get(reservation)
    end # allocated?(reservation)

    # Releases the whole allocation range
    def reset
      @free_set.clear
    end # reset



    protected

    # This implementation is significantly less efficient
    # that what the RabbitMQ Java client has (based on java.lang.Long#nextSetBit and
    # java.lang.Long.numberOfTrailingZeros, and thus binary search over bits).
    # But for channel id generation, this is a good enough implementation.
    #
    # @private
    def find_unallocated_position
      r = nil
      @range.each do |i|
        if !@free_set.get(i)
          r = i
          break;
        end
      end

      r
    end # find_unallocated_position
  end # IntAllocator
end # AMQP
