# encoding: utf-8

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'

AMQP.start(:host => 'localhost') do |connection|

  # Send Connection.Close on Ctrl+C
  trap(:INT) do
    unless connection.closing?
      connection.close { exit! }
    end
  end

  def log(*args)
    p [ Time.now, *args ]
  end

  def publish_stock_prices
    mq = AMQP::Channel.new
    EM.add_periodic_timer(1) {
      puts

      { :appl => 170+rand(1000)/100.0,
        :msft => 22+rand(500)/100.0
      }.each do |stock, price|
        stock = "usd.#{stock}"

        log :publishing, stock, price
        mq.topic('stocks').publish(price, :key => stock)
      end
    }
  end

  def watch_appl_stock
    mq = AMQP::Channel.new
    mq.queue('apple stock').bind(mq.topic('stocks'), :key => 'usd.appl').subscribe { |price|
      log 'apple stock', price
    }
  end

  def watch_us_stocks
    mq = AMQP::Channel.new
    mq.queue('us stocks').bind(mq.topic('stocks'), :key => 'usd.*').subscribe { |info, price|
      log 'us stock', info.routing_key, price
    }
  end

  publish_stock_prices
  watch_appl_stock
  watch_us_stocks

end

__END__

[Fri Aug 15 01:39:00 -0700 2008, :publishing, "usd.appl", 173.45]
[Fri Aug 15 01:39:00 -0700 2008, :publishing, "usd.msft", 26.98]
[Fri Aug 15 01:39:00 -0700 2008, "apple stock", "173.45"]
[Fri Aug 15 01:39:00 -0700 2008, "us stock", "usd.appl", "173.45"]
[Fri Aug 15 01:39:00 -0700 2008, "us stock", "usd.msft", "26.98"]

[Fri Aug 15 01:39:01 -0700 2008, :publishing, "usd.appl", 179.72]
[Fri Aug 15 01:39:01 -0700 2008, :publishing, "usd.msft", 26.56]
[Fri Aug 15 01:39:01 -0700 2008, "apple stock", "179.72"]
[Fri Aug 15 01:39:01 -0700 2008, "us stock", "usd.appl", "179.72"]
[Fri Aug 15 01:39:01 -0700 2008, "us stock", "usd.msft", "26.56"]
