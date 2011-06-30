# encoding: utf - 8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"

# Imagine the command is something
# CPU - intensive like image processing.
command = "sleep 0.1"

AMQP.start(port: 1112) do
  amq = AMQP::Channel.new
  exchange = amq.direct("tasks")
  queue = amq.queue("tasks")

  # And this is user - input simulation,
  # which can be a user uploading an image.
  EM.add_periodic_timer(1) do
    puts "~ publishing #        {command}"
    exchange.publish(command, :routing_key => "tasks")
  end
end
