# encoding: utf-8

$:.unshift File.expand_path("../../../lib", __FILE__)
require "amqp"

AMQP.start(:host => "localhost") do |connection|

  # Send Connection.Close on Ctrl+C
  trap(:INT) do
    unless connection.closing?
      connection.close { exit! }
    end
  end

  @counter = 0
  amq = MQ.new

  3.times do
    amq.queue("") do |queue|
      puts "Queue #{queue.name} declared."
      puts "All queues: #{amq.queues.map(&:name).inspect}", ""

      @counter += 1
    end
  end

  EM.add_periodic_timer(0.1) do
    EM.stop if @counter == 3
  end
end

__END__
Queue amq.gen-qeaCcyVCG50S6QC4U/zNoA== declared.
All queues: [nil, nil, "amq.gen-qeaCcyVCG50S6QC4U/zNoA=="]

Queue amq.gen-AinMI7PBa2n1fFRIaGEAog== declared.
All queues: [nil, "amq.gen-AinMI7PBa2n1fFRIaGEAog==", "amq.gen-qeaCcyVCG50S6QC4U/zNoA=="]

Queue amq.gen-ROdJW1LZJVJulUIh8KZqkw== declared.
All queues: ["amq.gen-ROdJW1LZJVJulUIh8KZqkw==", "amq.gen-AinMI7PBa2n1fFRIaGEAog==", "amq.gen-qeaCcyVCG50S6QC4U/zNoA=="]
