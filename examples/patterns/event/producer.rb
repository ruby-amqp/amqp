# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"
require "yaml"

t = Thread.new { EventMachine.run }
sleep(0.5)

connection = AMQP.connect
channel    = AMQP::Channel.new(connection)
exchange   = channel.fanout("amqpgem.patterns.events", :durable => true, :auto_delete => false)


EVENTS     = {
  "pages.show" => {
    :url      => "https://mysite.local/widgets/81772",
    :referrer => "http://www.google.com/search?client=safari&rls=en&q=widgets&ie=UTF-8&oe=UTF-8"
  },
  "widgets.created" => {
    :id       => 10,
    :shape    => "round",
    :owner_id => 1000
  },
  "widgets.destroyed" => {
    :id        => 10,
    :person_id => 1000
  },
  "files.created" => {
    :sha1      => "1a62429f47bc8b405d17e84b648f2fbebc555ee5",
    :filename  => "document.pdf"
  },
  "files.indexed" => {
    :sha1      => "1a62429f47bc8b405d17e84b648f2fbebc555ee5",
    :filename  => "document.pdf",
    :runtime   => 1.7623,
    :shared    => "shard02"
  }
}

def generate_event
  n       = (EVENTS.size * Kernel.rand).floor
  type    = EVENTS.keys[n]
  payload = EVENTS[type]

  [type, payload]
end

# broadcast events
EventMachine.add_periodic_timer(2.0) do
  event_type, payload = generate_event

  puts "Publishing a new event of type #{event_type}"
  exchange.publish(payload.to_yaml, :type => event_type)
end

puts "[boot] Ready. Will be publishing events every few seconds."
Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join
