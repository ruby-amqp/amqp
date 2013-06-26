# encoding: utf-8

require "amq/client/exceptions"

module AMQ
  module Client
    module Framing
      module IO

        class Frame < AMQ::Protocol::Frame
          def self.decode(io)
            header = io.read(7)
            type, channel, size = self.decode_header(header)
            data = io.read(size + 1)
            payload, frame_end = data[0..-2], data[-1, 1]
            # TODO: this will hang if the size is bigger than expected or it'll leave there some chars -> make it more error-proof:
            # BTW: socket#eof?
            raise NoFinalOctetError.new if frame_end != AMQ::Protocol::Frame::FINAL_OCTET
            self.new(type, payload, channel)
          end # self.from

        end # Frame
      end # IO
    end # Framing
  end # Client
end # AMQ
