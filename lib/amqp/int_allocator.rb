# encoding: utf-8

require "amq/int_allocator"

module AMQP
  # A forward reference for AMQP::IntAllocator that was extracted to amq-protocol
  # to make it possible to reuse it in Bunny.
  IntAllocator = AMQ::IntAllocator
end # AMQP
