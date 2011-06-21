module AMQP
  # Very minimalistic, pure Ruby implementation of bit set. Inspired by java.util.BitSet,
  # although significantly smaller in scope.
  class BitSet

    #
    # API
    #

    ADDRESS_BITS_PER_WORD = 6
    BITS_PER_WORD         = (1 << ADDRESS_BITS_PER_WORD)
    WORD_MASK             = 0xffffffffffffffff

    # @param [Integer] Number of bits in the set
    # @api public
    def initialize(nbits)
      @nbits = nbits

      self.init_words(nbits)
    end # initialize(nbits)

    # Sets (flags) given bit. This method allows bits to be set more than once in a row, no exception will be raised.
    #
    # @param [Integer] A bit to set
    # @api public
    def set(i)
      w = self.word_index(i)
      @words[w] |= (1 << i)
    end # set(i)

    # Fetches flag value for given bit.
    #
    # @param [Integer] A bit to fetch
    # @return [Boolean] true if given bit is set, false otherwise
    # @api public
    def get(i)
      w = self.word_index(i)

      (@words[w] & (1 << i)) != 0
    end # get(i)
    alias [] get

    # Unsets (unflags) given bit. This method allows bits to be unset more than once in a row, no exception will be raised.
    #
    # @param [Integer] A bit to unset
    # @api public
    def unset(i)
      w = self.word_index(i)
      return if w.nil?

      @words[w] &= ~(1 << i)
    end # unset(i)

    # Clears all bits in the set
    # @api public
    def clear
      self.init_words(@nbits)
    end # clear


    #
    # Implementation
    #

    protected

    # @private
    def init_words(nbits)
      n      = word_index(nbits-1) + 1
      @words = Array.new(n) { 1 }
    end # init_words

    # @private
    def word_index(i)
      i >> ADDRESS_BITS_PER_WORD
    end # word_index(i)
  end # BitSet
end # AMQP
