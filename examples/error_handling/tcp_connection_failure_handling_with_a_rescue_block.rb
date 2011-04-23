#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> TCP connection failure handling with a rescue statement"
puts

handler = Proc.new { |settings| puts "Failed to connect, as expected"; EM.stop }

begin
  AMQP.start(:port     => 9689,
             :vhost    => "/amq_client_testbed",
             :user     => "amq_client_gem",
             :password => "amq_client_gem_password",
             :timeout        => 0.3) do |connection, open_ok|
               raise "This should not be reachable"
  end
rescue AMQ::Client::TCPConnectionFailed => e
  puts "TCP connection failed, as expected"
end

