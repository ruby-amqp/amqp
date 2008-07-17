$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

EM.run{

  def log *args
    p [ Time.now, *args ]
  end

  # AMQP.logging = true

  amq = MQ.new
  amq.queue('hash table').subscribe{ |info, request|
    @hash ||= {}
    method, *args = Marshal.load(request)

    p ['server', method, *args]

    case method
    when :get
      amq.direct.publish(Marshal.dump(@hash[ args[0] ]), :key => info.reply_to, :message_id => info.message_id)
    when :set
      @hash[ args[0] ] = args[1]
    end
  }

  client = MQ.new.rpc('hash table')

  client.set(:now, time = Time.now)

  client.get(:now) do |res|
    p ['client', "hashtable[:now] = #{res}", res == time]
  end

}

__END__

["server", :set, :now, Thu Jul 17 16:50:14 -0700 2008]
["server", :get, :now]
["client", "hashtable[:now] = Thu Jul 17 16:50:14 -0700 2008", true]