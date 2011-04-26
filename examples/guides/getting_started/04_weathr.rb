#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

EventMachine.run do
  AMQP.connect do |connection|
    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic("pub/sub", :auto_delete => true)

    # Subscribers.
    channel.queue("", :exclusive => true) do |queue|
      queue.bind(exchange, :routing_key => "americas.north.#").subscribe do |headers, payload|
        puts "An update for North America: #{payload}, routing key is #{headers.routing_key}"
      end
    end
    channel.queue("americas.south").bind(exchange, :routing_key => "americas.south.#").subscribe do |headers, payload|
      puts "An update for South America: #{payload}, routing key is #{headers.routing_key}"
    end
    channel.queue("us.california").bind(exchange, :routing_key => "americas.north.us.ca.*").subscribe do |headers, payload|
      puts "An update for US/California: #{payload}, routing key is #{headers.routing_key}"
    end
    channel.queue("us.tx.austin").bind(exchange, :routing_key => "#.tx.austin").subscribe do |headers, payload|
      puts "An update for Austin, TX: #{payload}, routing key is #{headers.routing_key}"
    end
    channel.queue("it.rome").bind(exchange, :routing_key => "europe.italy.rome").subscribe do |headers, payload|
      puts "An update for Rome, Italy: #{payload}, routing key is #{headers.routing_key}"
    end
    channel.queue("asia.hk").bind(exchange, :routing_key => "asia.southeast.hk.#").subscribe do |headers, payload|
      puts "An update for Hong Kong: #{payload}, routing key is #{headers.routing_key}"
    end

    EM.add_timer(1) do
      exchange.publish("San Diego update", :routing_key => "americas.north.us.ca.sandiego").
        publish("Berkeley update",         :routing_key => "americas.north.us.ca.berkeley").
        publish("San Francisco update",    :routing_key => "americas.north.us.ca.sanfrancisco").
        publish("New York update",         :routing_key => "americas.north.us.ny.newyork").
        publish("São Paolo update",        :routing_key => "americas.south.brazil.saopaolo").
        publish("Hong Kong update",        :routing_key => "asia.southeast.hk.hongkong").
        publish("Kyoto update",            :routing_key => "asia.southeast.japan.kyoto").
        publish("Shanghai update",         :routing_key => "asia.southeast.prc.shanghai").
        publish("Rome update",             :routing_key => "europe.italy.roma").
        publish("Paris update",            :routing_key => "europe.france.paris")
    end


    show_stopper = Proc.new {
      connection.close do
        EM.stop
      end
    }

    EM.add_timer(2, show_stopper)
  end
end
