#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Connection loss is detected and handled"
puts
AMQP.start(:port     => 5672,
           :vhost    => "amq_client_testbed",
           :user     => "amq_client_gem",
           :password => "amq_client_gem_password",
           :timeout    => 0.3,
           :heartbeat  => 1.0,
           :on_tcp_connection_failure => Proc.new { |settings| puts "Failed to connect, this was NOT expected"; EM.stop }) do |connection, open_ok|
    connection.on_tcp_connection_loss do |cl, settings|
      puts "tcp_connection_loss handler kicks in"
      cl.reconnect(false, 1)
    end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close { EventMachine.stop }
  end

  puts "Connected, authenticated. To really exercise this example, shut RabbitMQ down for a few seconds. If you don't it will exit gracefully in 30 seconds."

  Signal.trap "INT",  show_stopper
  EM.add_timer(60, show_stopper)
end
