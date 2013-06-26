# encoding: utf-8

require "amq/client/async/channel"

# Basic.Cancel
module AMQ
  module Client
    module Async
      module Extensions
        module RabbitMQ
          module Basic
            module ConsumerMixin
            end # ConsumerMixin

            module QueueMixin
            end

          end # Basic
        end # RabbitMQ
      end # Extensions
    end # Async
  end # Client
end # AMQ
