module AMQP
  module Openable
    VALUES = [:opened, :closed, :opening, :closing].freeze

    class ImproperStatusError < ArgumentError
      def initialize(value)
        super("Value #{value.inspect} isn't permitted. Choose one of: #{AMQP::Openable::VALUES.inspect}")
      end
    end

    attr_reader :status
    def status=(value)
      if VALUES.include?(value)
        @status = value
      else
        raise ImproperStatusError.new(value)
      end
    end

    def opened?
      @status == :opened
    end
    alias open? opened?

    def closed?
      @status == :closed
    end



    def opening?
      @status == :opening
    end

    def closing?
      @status == :closing
    end


    def opened!
      @status = :opened
    end # opened!

    def closed!
      @status = :closed
    end # closed!



    def opening!
      @status = :opening
    end # opening!

    def closing!
      @status = :closing
    end # closing!
  end
end
