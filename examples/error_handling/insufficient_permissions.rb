#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue redeclaration with different attributes results in a channel exception that is handled"
puts
AMQP.start(:vhost => "amqp_gem_testbed", :username => "amqp_gem_reader", :password => "reader_password") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    channel.on_error do |ch, channel_close|
      puts <<-ERR
      Handling a channel-level exception.

      AMQP class id : #{channel_close.class_id},
      AMQP method id: #{channel_close.method_id},
      Status code   : #{channel_close.reply_code}
      Error message : #{channel_close.reply_text}
      ERR
    end

    EventMachine.add_timer(0.4) do
      # these two definitions result in a race condition. For sake of this example,
      # however, it does not matter. Whatever definition succeeds first, 2nd one will
      # cause a channel-level exception (because attributes are not identical)
      AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => false) do |queue|
        puts "#{queue.name} is ready to go"
      end

      AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => true) do |queue|
        puts "#{queue.name} is ready to go"
      end
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."

    connection.close {
      EM.stop { exit }
    }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(2, show_stopper)
end
