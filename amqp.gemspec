#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/amqp/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "amqp"
  s.version = AMQP::VERSION
  s.authors = ["Aman Gupta", "Jakub Stastny aka botanicus"]
  s.homepage = "http://github.com/tmm1/amqp"
  s.summary = "AMQP client implementation in Ruby/EventMachine."
  s.description = "An implementation of the AMQP protocol in Ruby/EventMachine for writing clients to the RabbitMQ message broker."
  s.cert_chain = nil
  s.email = Base64.decode64("c3Rhc3RueUAxMDFpZGVhcy5jeg==\n")

  # files
  s.files = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  # RDoc
  s.has_rdoc = true
  s.rdoc_options = '--include=examples'
  s.extra_rdoc_files = ["README.md"] + Dir.glob("doc/*")

  # Dependencies
  s.add_dependency "eventmachine", ">= 0.12.4"

  begin
    require "changelog"
  rescue LoadError
    warn "You have to have changelog gem installed for post install message"
  else
    s.post_install_message = CHANGELOG.new.version_changes
  end

  # RubyForge
  s.rubyforge_project = "amqp"
end
