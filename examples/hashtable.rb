$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

EM.run{

  def log *args
    p [ Time.now, *args ]
  end

  # AMQP.logging = true

  module HashTable
    def [] key
      p [HashTable, :get, key]
      hash[key]
    end
    alias :get :[]
    
    def []= key, value
      p [HashTable, :set, key, value]
      hash[key] = value
    end
    alias :set :[]=
    
    private
    
    def hash
      @hash ||= {}
    end

    MQ.new.rpc('hash table', self)
  end

  client = MQ.new.rpc('hash table')
  client[:now] = time = Time.now
  client.get(:now) do |res|
    p ['client', "hashtable[:now] = #{res}", res == time]
  end

}

__END__

[HashTable, :set, :now, Thu Jul 17 17:05:18 -0700 2008]
[HashTable, :get, :now]
["client", "hashtable[:now] = Thu Jul 17 17:05:18 -0700 2008", true]