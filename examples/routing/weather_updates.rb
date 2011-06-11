#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require "amqp"

EventMachine.run do
  AMQP.connect do |connection|
    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic("pub/sub", :auto_delete => true)

    # Subscribers.
    channel.queue("", :exclusive => true) do |queue|
      queue.bind(exchange, :routing_key => "americas.north.#").subscribe do |metadata, payload|
        puts "An update for North America: #{payload}, routing key is #{metadata.routing_key}"
      end
    end
    channel.queue("americas.south").bind(exchange, :routing_key => "americas.south.#").subscribe do |metadata, payload|
      puts "An update for South America: #{payload}, routing key is #{metadata.routing_key}"
    end
    channel.queue("us.california").bind(exchange, :routing_key => "americas.north.us.ca.*").subscribe do |metadata, payload|
      puts "An update for US/California: #{payload}, routing key is #{metadata.routing_key}"
    end
    channel.queue("us.tx.austin").bind(exchange, :routing_key => "#.tx.austin").subscribe do |metadata, payload|
      puts "An update for Austin, TX: #{payload}, routing key is #{metadata.routing_key}"
    end
    channel.queue("it.rome").bind(exchange, :routing_key => "europe.italy.rome").subscribe do |metadata, payload|
      puts "An update for Rome, Italy: #{payload}, routing key is #{metadata.routing_key}"
    end
    channel.queue("asia.hk").bind(exchange, :routing_key => "asia.southeast.hk.#").subscribe do |metadata, payload|
      puts "An update for Hong Kong: #{payload}, routing key is #{metadata.routing_key}"
    end

    # publish a bunch of messages after 1 second, when all queues are declared and bound
    EventMachine.add_timer(1) do
      exchange.publish("San Diego update", :routing_key => "americas.north.us.ca.sandiego").
        publish("Berkeley update",        :routing_key => "americas.north.us.ca.berkeley").
        publish("San Francisco update",    :routing_key => "americas.north.us.ca.sanfrancisco").
        publish("New York update",         :routing_key => "americas.north.us.ny.newyork").
        publish("São Paolo update",        :routing_key => "americas.south.brazil.saopaolo").
        publish("Hong Kong update",        :routing_key => "asia.southeast.hk.hongkong").
        publish("Kyoto update",            :routing_key => "asia.southeast.japan.kyoto").
        publish("Shanghai update",         :routing_key => "asia.southeast.prc.shanghai").
        publish("Rome update",             :routing_key => "europe.italy.roma").
        publish("Paris update",            :routing_key => "europe.france.paris")
    end


    show_stopper = Proc.new { connection.close { EventMachine.stop } }
    Signal.trap "TERM", show_stopper

    EM.add_timer(3, show_stopper)
  end
end
