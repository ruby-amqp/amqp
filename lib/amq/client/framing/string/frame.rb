# encoding: utf-8

# This will be probably used by all the async libraries like EventMachine.
# It expects the whole frame as one string, so if library of your choice
# gives you input chunk-by-chunk, you'll need to have something like this:
#
# class Client
#   include EventMachine::Deferrable
#
#   def receive_data(chunk)
#     if @payload.nil?
#       self.decode_from_string(chunk[0..6])
#       @payload = ""
#     elsif @payload && chunk[-1] != FINAL_OCTET
#       @payload += chunk
#       @size += chunk.bytesize
#     else
#       check_size(@size, @payload.bytesize)
#       Frame.decode(@payload) # we need the whole payload
#       @size, @payload = nil
#     end
#   end
#
#   NOTE: the client should also implement waiting for another frames, in case that some header/body frames are expected.
# end

require "amq/client/exceptions"

module AMQ
  module Client
    module Framing
      module String
        class Frame < AMQ::Protocol::Frame
          ENCODINGS_SUPPORTED = defined? Encoding
          HEADER_SLICE = (0..6).freeze
          DATA_SLICE = (7..-1).freeze
          PAYLOAD_SLICE = (0..-2).freeze

          def self.decode(string)
            header              = string[HEADER_SLICE]
            type, channel, size = self.decode_header(header)
            data                = string[DATA_SLICE]
            payload             = data[PAYLOAD_SLICE]
            frame_end           = data[-1, 1]

            frame_end.force_encoding(AMQ::Protocol::Frame::FINAL_OCTET.encoding) if ENCODINGS_SUPPORTED

            # 1) the size is miscalculated
            if payload.bytesize != size
              raise BadLengthError.new(size, payload.bytesize)
            end

            # 2) the size is OK, but the string doesn't end with FINAL_OCTET
            raise NoFinalOctetError.new if frame_end != AMQ::Protocol::Frame::FINAL_OCTET

            self.new(type, payload, channel)
          end # self.from
        end # Frame
      end # String
    end # Framing
  end # Client
end # AMQ
