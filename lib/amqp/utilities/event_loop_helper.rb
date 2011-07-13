# encoding: utf-8

require "eventmachine"
require "amqp/utilities/server_type"

require "thread"

module AMQP
  module Utilities

    # A helper that starts EventMachine reactor the optimal way depending on what Web server
    # (if any) you are running. It should not be considered a 100% safe, general purpose EventMachine
    # reactor "on/off switch" but is very useful in Web applications and some stand-alone applications.
    #
    # This helper was inspired by Qusion project by Dan DeLeo.
    #
    # h2. Key methods
    #
    # * {EventLoopHelper.run}
    # * {EventLoopHelper.server_type}
    class EventLoopHelper

      def self.eventmachine_thread
        @eventmachine_thread
      end # self.eventmachine_thread

      def self.reactor_running?
        EventMachine.reactor_running?
      end # self.reactor_running?

      # Type of server (if any) that is running.
      #
      # @see AMQP::Utilities::ServerType.detect
      def self.server_type
        @server_type ||= ServerType.detect
      end # self.server_type

      # A helper that detects what app server (if any) is running and starts
      # EventMachine reactor in the most optimal way. For event-driven servers like
      # Thin and Goliath, this means relying on them starting the reactor but delaying
      # execution of a block you pass to {EventLoopHelper.run} until reactor is actually running.
      #
      # For Unicorn, Passenger, Mongrel and other servers and standalone apps EventMachine is started
      # in a separate thread.
      #
      # @example Using EventLoopHelper.run to start EventMachine reactor the optimal way without blocking current thread
      #
      #   AMQP::Utilities::EventLoopHelper.run do
      #     # Sets up default connection, accessible via AMQP.connection, and opens a channel
      #     # accessible via AMQP.channel for convenience
      #     AMQP.start
      #
      #     exchange          = AMQP.channel.fanout("amq.fanout")
      #
      #     AMQP.channel.queue("", :auto_delete => true, :exclusive => true).bind(exchange)
      #     AMQP::channel.default_exchange.publish("Started!", :routing_key => AMQP::State.queue.name)
      #   end
      #
      # @return [Thread] A thread EventMachine event loop will be started in (there is no guarantee it is already running).
      #
      #
      # @note This method, unlike EventMachine.run, DOES NOT block current thread.
      def self.run(&block)
        if reactor_running?
          EventMachine.run(&block)

          return
        end

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

        @eventmachine_thread
      end # self.run


    end # EventLoopHelper
  end # Utilities
end # AMQP
