# encoding: utf - 8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"

t = Thread.new { EventMachine.run }
sleep(0.5)


connection = AMQP.connect
channel    = AMQP::Channel.new(connection, :auto_recovery => true)

channel.prefetch(1)

# Acknowledgements are good for letting the server know
# that the task is finished. If the consumer doesn't send
# the acknowledgement, then the task is considered to be unfinished
# and will be requeued when consumer closes AMQP connection (because of a crash, for example).
channel.queue("amqpgem.examples.tasks", :durable => true, :auto_delete => false).subscribe(:ack => true) do |metadata, payload|
  puts payload
  puts system(payload)

  puts
  puts "[done] Done with #{payload}"
  puts

  # message is processed, acknowledge it so that broker
  # removes it
  metadata.ack
end


Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join

