require "eventmachine"
require "amqp/utilities/server_type"

require "thread"

module AMQP
  module Utilities
    class EventLoopHelper

      def self.eventmachine_thread
        @eventmachine_thread
      end # self.eventmachine_thread

      def self.reactor_running?
        EventMachine.reactor_running?
      end # self.reactor_running?

      def self.server_type
        @server_type ||= ServerType.detect
      end # self.server_type

      def self.run(&block)
        @eventmachine_thread  ||= begin
                                    case self.server_type
                                    when :thin, :goliath, :evented_mongrel then
                                      EventMachine.next_tick { block.call }
                                      Thread.current
                                    when :unicorn, :passenger, :mongrel, :scgi, :webrick, nil then
                                      t = Thread.new { EventMachine.run(&block) }
                                      # give EventMachine reactor some time to start
                                      sleep(0.25)

                                      t
                                    else
                                      t = Thread.new { EventMachine.run(&block) }
                                      # give EventMachine reactor some time to start
                                      sleep(0.25)

                                      t
                                    end
                                  end
      end # self.run


    end # EventLoopHelper
  end # Utilities
end # AMQP
