# encoding: utf-8

# Purpose of this class is to simplify work with GetOk and GetEmpty.
module AMQ
  module Protocol
    class GetResponse
      attr_reader :method
      def initialize(method)
        @method = method
      end

      def empty?
        @method.is_a?(::AMQ::Protocol::Basic::GetEmpty)
      end

      # GetOk attributes
      def delivery_tag
        if @method.respond_to?(:delivery_tag)
          @method.delivery_tag
        end
      end

      def redelivered
        if @method.respond_to?(:redelivered)
          @method.redelivered
        end
      end

      def exchange
        if @method.respond_to?(:exchange)
          @method.exchange
        end
      end

      def routing_key
        if @method.respond_to?(:routing_key)
          @method.routing_key
        end
      end

      def message_count
        if @method.respond_to?(:message_count)
          @method.message_count
        end
      end

      # GetEmpty attributes
      def cluster_id
        if @method.respond_to?(:cluster_id)
          @method.cluster_id
        end
      end
    end
  end
end
