#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Headers routing example"
puts
AMQP.start do |connection|
  channel   = AMQP::Channel.new(connection)
  channel.on_error do |ch, channel_close|
    puts "A channel-level exception: #{channel_close.inspect}"
  end

  exchange = channel.headers("amq.match", :durable => true)

  channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'all', :arch => "ia64", :os => 'linux' }).subscribe do |metadata, payload|
    puts "[linux/ia64] Got a message: #{payload}"
  end
  channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'all', :arch => "x86", :os => 'linux' }).subscribe do |metadata, payload|
    puts "[linux/x86] Got a message: #{payload}"
  end
  channel.queue("", :auto_delete => true).bind(exchange, :arguments => { :os => 'linux'}).subscribe do |metadata, payload|
    puts "[linux] Got a message: #{payload}"
  end
  channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'any', :os => 'macosx', :cores => 8 }).subscribe do |metadata, payload|
    puts "[macosx|octocore] Got a message: #{payload}"
  end
  channel.queue("", :auto_delete => true).bind(exchange, :arguments => { :package => { :name => 'riak', :version => '0.14.2' } }).subscribe do |metadata, payload|
    puts "[riak/0.14.2] Got a message: #{payload}"
  end

  EventMachine.add_timer(0.5) do
    exchange.publish "For linux/ia64",   :headers => { :arch => "ia64", :os => 'linux' }
    exchange.publish "For linux/x86",    :headers => { :arch => "x86", :os => 'linux'  }
    exchange.publish "For linux",        :headers => { :os => 'linux'  }
    exchange.publish "For OS X",         :headers => { :os => 'macosx' }
    exchange.publish "For solaris/ia64", :headers => { :os => 'solaris', :arch => 'ia64' }
    exchange.publish "For ocotocore",    :headers => { :cores => 8  }

    exchange.publish "For nodes with Riak 0.14.2", :headers => { :package => { :name => 'riak', :version => '0.14.2' } }
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close { EventMachine.stop }
  end

  Signal.trap "INT", show_stopper
  EventMachine.add_timer(2, show_stopper)
end
