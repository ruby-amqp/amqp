# encoding: utf - 8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"

# Imagine we have for example 10 servers, on each of them runs this
# script, just the server_name variable will be different on each of them.
server_name = "server - 1"

AMQP.start do
  amq = AMQP::Channel.new

  # Tasks distribution has to be based on load on each clients rather
  # than on the number of distributed messages. (The default behaviour
  # is to dispatches every n - th message to the n - th consumer.
  amq.prefetch(1)

  # Acknowledgements are good for letting the server know
  # that the task is finished. If the consumer doesn't send
  # the acknowledgement, then the task is considered to be unfinished.
  amq.queue(server_name).subscribe(:ack => true) do |h, message|
    puts message
    puts system(message)
    h.ack
  end
end
