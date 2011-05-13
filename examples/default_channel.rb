# encoding: utf-8

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'

AMQP.start(:host => 'localhost') do |connection|

  # Send Connection.Close on Ctrl+C
  trap(:INT) do
    AMQP.stop do
      puts "Closing and AMQP.channel is #{AMQP.channel.open? ? 'open' : 'closed'}"
      exit
    end
  end

  puts "AMQP.connection is #{AMQP.connection}"
  puts "AMQP.channel is #{AMQP.channel}"

end