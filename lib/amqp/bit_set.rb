# encoding: utf-8

require "amq/bit_set"

module AMQP
  # A forward reference for AMQP::BitSet that was extracted to amq-protocol
  # to make it possible to reuse it in Bunny.
  BitSet = AMQ::BitSet
end # AMQP
