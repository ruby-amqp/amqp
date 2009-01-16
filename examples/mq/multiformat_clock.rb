$:.unshift File.dirname(__FILE__) + '/../../lib'
require 'mq'
require 'time'
EM.run{

  def log *args
    p args
  end

  #AMQP.logging = true

  clock = MQ.new.headers('multiformat_clock')
  EM.add_periodic_timer(1){
    puts

    time = Time.new
    ["iso8601","rfc2822"].each do |format|
      formatted_time = time.send(format)
      log :publish, format, formatted_time
      clock.publish "#{formatted_time}", :headers => {"format" => format}
    end
  }

  ["iso8601","rfc2822"].each do |format|
    amq = MQ.new
    amq.queue(format.to_s).bind(amq.headers('multiformat_clock'), :arguments => {"format" => format}).subscribe{ |time|
      log "received #{format}", time
    }
  end


}

__END__
