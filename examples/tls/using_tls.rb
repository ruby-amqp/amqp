#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

examples_dir = File.join(File.dirname(File.expand_path(__FILE__)), "..")

certificate_chain_file_path  = File.join(examples_dir, "tls_certificates", "client", "cert.pem")
client_private_key_file_path = File.join(examples_dir, "tls_certificates", "client", "key.pem")


require 'amqp'

AMQP.start(:port     => 5671,
           :ssl => {
             :cert_chain_file  => certificate_chain_file_path,
             :private_key_file => client_private_key_file_path
           }) do |connection|
  puts "Connected, authenticated. TLS seems to work."

  connection.disconnect { puts "Now closing the connection…"; EventMachine.stop }
end
