#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


AMQP.start do |session|
  ch             = AMQP::Channel.new(session)
  exchange       = ch.fanout("amq.fanout")
  reply_exchange = ch.default_exchange

  ch.queue("", :exclusive => true) do |q1|
    q1.bind(exchange).subscribe do |header, payload|
      v = rand

      puts "Replying to #{header.message_id} with #{v}"
      reply_exchange.publish(v, :routing_key => header.reply_to, :message_id => header.message_id)
    end
  end
  ch.queue("", :exclusive => true) do |q2|
    q2.bind(exchange).subscribe do |header, payload|
      v = rand

      puts "Replying to #{header.message_id} with #{v}"
      reply_exchange.publish(v, :routing_key => header.reply_to, :message_id => header.message_id)
    end
  end
  ch.queue("", :exclusive => true) do |q3|
    q3.bind(exchange).subscribe do |header, payload|
      v = rand

      puts "Replying to #{header.message_id} with #{v}"
      reply_exchange.publish(v, :routing_key => header.reply_to, :message_id => header.message_id)
    end
  end


  requests = Hash.new

  EventMachine.add_timer(0.5) do
    ch.queue("", :exlusive => true) do |q|
      q.subscribe do |header, payload|
        requests[header.message_id].push(payload)

        puts "Got a reply for #{header.message_id}"

        if requests[header.message_id].size == 3
          puts "Gathered all 3 responses: #{requests[header.message_id].join(', ')}"
          requests[header.message_id].clear
        end
      end


      message_id           = "__message #{rand}__"
      requests[message_id] = Array.new

      exchange.publish("a request", :reply_to => q.name, :message_id => message_id)
    end
  end


  EventMachine.add_timer(2) do
    session.close { EventMachine.stop }
  end
end
