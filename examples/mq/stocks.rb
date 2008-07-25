$:.unshift File.dirname(__FILE__) + '/../../lib'
require 'mq'

EM.run{

  def log *args
    p [ Time.now, *args ]
  end

  # AMQP.logging = true

  EM.add_periodic_timer(1){
    puts

    log :publishing, 'stock.usd.appl', price = 170+rand(1000)/100.0
    MQ.topic.publish(price, :key => 'stock.usd.appl', :headers => {:symbol => 'appl'})

    log :publishing, 'stock.usd.msft', price = 22+rand(500)/100.0
    MQ.topic.publish(price, :key => 'stock.usd.msft', :headers => {:symbol => 'msft'})
  }

  Thread.new{
    amq = MQ.new
    amq.queue('apple stock').bind(amq.topic, :key => 'stock.usd.appl').subscribe{ |price|
      log 'apple stock', price
    }
  }

  Thread.new{
    amq = MQ.new
    amq.queue('us stocks').bind(amq.topic, :key => 'stock.usd.*').subscribe{ |info, price|
      log 'us stock', info.headers[:symbol], price
    }
  }

}

__END__

[Thu Jul 17 14:51:07 -0700 2008, :publishing, "stock.usd.appl", 170.84]
[Thu Jul 17 14:51:07 -0700 2008, :publishing, "stock.usd.msft", 23.68]
[Thu Jul 17 14:51:07 -0700 2008, "apple stock", "170.84"]
[Thu Jul 17 14:51:07 -0700 2008, "us stock", "appl", "170.84"]
[Thu Jul 17 14:51:07 -0700 2008, "us stock", "msft", "23.68"]

[Thu Jul 17 14:51:08 -0700 2008, :publishing, "stock.usd.appl", 173.61]
[Thu Jul 17 14:51:08 -0700 2008, :publishing, "stock.usd.msft", 25.8]
[Thu Jul 17 14:51:08 -0700 2008, "apple stock", "173.61"]
[Thu Jul 17 14:51:08 -0700 2008, "us stock", "appl", "173.61"]
[Thu Jul 17 14:51:08 -0700 2008, "us stock", "msft", "25.8"]

[Thu Jul 17 14:51:09 -0700 2008, :publishing, "stock.usd.appl", 173.94]
[Thu Jul 17 14:51:09 -0700 2008, :publishing, "stock.usd.msft", 24.88]
[Thu Jul 17 14:51:09 -0700 2008, "apple stock", "173.94"]
[Thu Jul 17 14:51:09 -0700 2008, "us stock", "appl", "173.94"]
[Thu Jul 17 14:51:09 -0700 2008, "us stock", "msft", "24.88"]
