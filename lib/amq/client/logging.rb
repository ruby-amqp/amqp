# encoding: utf-8

# You can use arbitrary logger which responds to #debug, #info, #error and #fatal methods, so for example the logger from standard library will work fine:
#
# AMQ::Client.logging = true
# AMQ::Client.logger  = MyLogger.new(STDERR)
#
# AMQ::Client.logger defaults to a new instance of Ruby stdlib logger.
#
# If you want to be able to log messages just from specified classes or even instances, just make the instance respond to #logging and set it to desired value. So for example <tt>Queue.class_eval { def logging; true; end }</tt> will turn on logging for the whole Queue class whereas <tt>queue = Queue.new; def queue.logging; false; end</tt> will disable logging for given Queue instance.

module AMQ
  module Client
    module Logging
      def self.included(klass)
        unless klass.method_defined?(:client)
          raise NotImplementedError.new("Class #{klass} has to provide #client method!")
        end
      end

      def self.logging
        @logging ||= false
      end

      def self.logging=(boolean)
        @logging = boolean
      end

      REQUIRED_METHODS = [:debug, :info, :error, :fatal].freeze

      def debug(message)
        log(:debug, message)
      end

      def info(message)
        log(:info, message)
      end

      def error(message)
        log(:error, message)
      end

      def fatal(message)
        log(:fatal, message)
      end

      protected
      def log(method, message)
        if self.respond_to?(:logging) ? self.logging : AMQ::Client::Logging.logging
          self.client.logger.__send__(method, message)
          message
        end
      end
    end
  end
end
