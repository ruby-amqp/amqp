class MQ
  class Exchange
    include AMQP

    def initialize mq, type, name, opts = {}
      @mq = mq
      @type, @name = type, name
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
        @mq.send Protocol::Basic::Publish.new({ :exchange => name,
                                                :routing_key => opts.delete(:key) || @key }.merge(opts))
      
        data = data.to_s

        @mq.send Protocol::Header.new(Protocol::Basic,
                                          data.length, { :content_type => 'application/octet-stream',
                                                         :delivery_mode => (opts.delete(:persistent) ? 2 : 1),
                                                         :priority => 0 }.merge(opts))
        @mq.send Frame::Body.new(data)
      }
      self
    end
  end
end