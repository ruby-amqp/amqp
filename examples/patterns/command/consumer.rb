# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"
require "yaml"

t = Thread.new { EventMachine.run }
sleep(0.5)


connection = AMQP.connect
channel    = AMQP::Channel.new(connection, :auto_recovery => true)

channel.prefetch(1)

# Acknowledgements are good for letting the server know
# that the task is finished. If the consumer doesn't send
# the acknowledgement, then the task is considered to be unfinished
# and will be requeued when consumer closes AMQP connection (because of a crash, for example).
channel.queue("amqpgem.examples.patterns.command", :durable => true, :auto_delete => false).subscribe(:ack => true) do |metadata, payload|
  case metadata.type
  when "gems.install"
    data = YAML.load(payload)
    puts "[gems.install] Received a 'gems.install' request with #{data.inspect}"

    # just to demonstrate a realistic example
    shellout = "gem install #{data[:gem]} --version '#{data[:version]}'"
    puts "[gems.install] Executing #{shellout}"; system(shellout)

    puts
    puts "[gems.install] Done"
    puts
  else
    puts "[commands] Unknown command: #{metadata.type}"
  end

  # message is processed, acknowledge it so that broker discards it
  metadata.ack
end

puts "[boot] Ready"
Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join

