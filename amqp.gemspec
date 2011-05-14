#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/amqp/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "amqp"
  s.version = AMQP::VERSION
  s.authors = ["Aman Gupta", "Jakub Stastny aka botanicus", "Michael S. Klishin"]
  s.homepage = "http://github.com/ruby-amqp/amqp"
  s.summary = "AMQP client implementation in Ruby/EventMachine."
  s.description = "Asynchronous AMQP 0.9.1 client for Ruby. Built on top of Eventmachine."
  s.email = ["bWljaGFlbEBub3ZlbWJlcmFpbi5jb20=\n", "c3Rhc3RueUAxMDFpZGVhcy5jeg==\n"].map { |i| Base64.decode64(i) }

  # files
  s.files = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  # RDoc
  s.rdoc_options = '--include=examples --main README.md'
  s.extra_rdoc_files = ["README.md"] + Dir.glob("doc/*")

  # Dependencies
  s.add_dependency "eventmachine"

  # RubyForge
  s.rubyforge_project = "amqp"
end
