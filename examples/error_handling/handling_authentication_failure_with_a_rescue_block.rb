#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Authentication failure handling with a rescue block"
puts

handler             = Proc.new { |settings| puts "Failed to connect, as expected"; EM.stop }
connection_settings = {
  :port     => 5672,
  :vhost    => "/amq_client_testbed",
  :user     => "amq_client_gem",
  :password => "amq_client_gem_password_that_is_incorrect #{Time.now.to_i}",
  :timeout        => 0.3,
  :on_tcp_connection_failure => handler
}


begin
  AMQP.start(connection_settings) do |connection, open_ok|
    raise "This should not be reachable"
  end
rescue AMQP::PossibleAuthenticationFailureError => afe
  puts "Authentication failed, as expected, caught #{afe.inspect}"
  EventMachine.stop if EventMachine.reactor_running?
end
