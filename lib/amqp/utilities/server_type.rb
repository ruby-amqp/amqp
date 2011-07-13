# encoding: utf-8

# Original version is from Qusion project by Daniel DeLeo.
#
# Copyright (c) 2009 Daniel DeLeo
# Copyright (c) 2011 Michael Klishin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

module AMQP
  module Utilities
    # A helper that detects Web server that may be running (if any). Partially derived
    # from Qusion project by Daniel DeLeo.
    class ServerType

      # Return a symbol representing Web server that is running (if any).
      #
      # Possible values are:
      #
      #  * :thin for Thin
      #  * :unicorn for Unicorn
      #  * :passenger for Passenger (Apache mod_rack)
      #  * :goliath for PostRank's Goliath
      #  * :evented_mongrel for Swiftiply's Evented Mongrel
      #  * :mongrel for Mongrel
      #  * :scgi for SCGI
      #  * :webrick for WEBrick
      #  * nil: none of the above (the case for non-Web application, for example)
      #
      # @return [Symbol]
      def self.detect
        if defined?(::PhusionPassenger)
          :passenger
        elsif defined?(::Unicorn)
          :unicorn
        elsif defined?(::Thin)
          :thin
        elsif defined?(::Goliath)
          :goliath
        elsif defined?(::Mongrel) && defined?(::Mongrel::MongrelProtocol)
          :evented_mongrel
        elsif defined?(::Mongrel)
          :mongrel
        elsif defined?(::SCGI)
          :scgi
        elsif defined?(::WEBrick)
          :webrick
        else
          nil
        end # if
      end # self.detect
    end # ServerType
  end # Utilities
end # AMQP
