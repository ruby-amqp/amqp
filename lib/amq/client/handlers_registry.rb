# encoding: utf-8

module AMQ
  module Client
    class HandlersRegistry

      @@handlers ||= Hash.new


      #
      # API
      #


      def self.register(klass, &block)
        @@handlers[klass] = block
      end
      class << self
        alias handle register
      end

      def self.find(klass)
        @@handlers[klass]
      end

      def self.handlers
        @@handlers
      end

    end # HandlersRegistry
  end # Client
end # AMQ