class MQ
  class Exchange
    include AMQP

    def initialize mq, type, name, opts = {}
      @mq = mq
      @type, @name, @opts = type, name, opts
      @mq.exchanges[@name = name] ||= self
      @key = opts[:key]

      @mq.callback{
        @mq.send Protocol::Exchange::Declare.new({ :exchange => name,
                                                   :type => type,
                                                   :nowait => true }.merge(opts))
      } unless name == "amq.#{type}" or name == ''
    end
    attr_reader :name, :type, :key

    def publish data, opts = {}
      @mq.callback{
        out = []

        out << Protocol::Basic::Publish.new({ :exchange => name,
                                              :routing_key => opts.delete(:key) || @key }.merge(opts))

        data = data.to_s

        out << Protocol::Header.new(Protocol::Basic,
                                    data.length, { :content_type => 'application/octet-stream',
                                                   :delivery_mode => (opts.delete(:persistent) ? 2 : 1),
                                                   :priority => 0 }.merge(opts))

        out << Frame::Body.new(data)

        @mq.send *out
      }
      self
    end

    def delete opts = {}
      @mq.callback{
        @mq.send Protocol::Exchange::Delete.new({ :exchange => name,
                                                  :nowait => true }.merge(opts))
        @mq.exchanges.delete name
      }
      nil
    end

    def reset
      @deferred_status = nil
      initialize @mq, @type, @name, @opts
    end
  end
end