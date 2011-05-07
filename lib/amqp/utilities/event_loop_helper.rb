require "eventmachine"
require "amqp/utilities/server_type"

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

      def self.run(in_a_worker_process = false)
        # TODO: make reentrant

        @eventmachine_thread  = case self.server_type
                                when :thin, :goliath, :evented_mongrel then
                                  Thread.current
                                when :unicorn, :passenger then
                                  EventMachine.stop if in_a_worker_process

                                  t = Thread.new { EventMachine.run }
                                  # give EventMachine reactor some time to start
                                  sleep(0.25)

                                  t
                                when :mongrel, :scgi, :webrick, nil then
                                  t = Thread.new { EventMachine.run }
                                  # give EventMachine reactor some time to start
                                  sleep(0.25)

                                  t
                                end
      end # self.run

      def self.stop
        EventMachine.stop
      end
    end # EventLoopHelper
  end # Utilities
end # AMQP
