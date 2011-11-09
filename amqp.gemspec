#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/amqp/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "amqp"
  s.version = AMQP::VERSION
  s.authors = ["Aman Gupta", "Jakub Stastny aka botanicus", "Michael S. Klishin"]
  s.homepage = "http://github.com/ruby-amqp/amqp"
  s.summary = "Widely used, feature-rich asynchronous AMQP 0.9.1 client with batteries included"
  # RubyGems will emit warnings if summary is the same as description. I have no idea why but lets trick it. MK.
  s.description = "Widely used, feature-rich asynchronous AMQP 0.9.1 client with batteries included."
  s.email = ["bWljaGFlbEBub3ZlbWJlcmFpbi5jb20=\n", "c3Rhc3RueUAxMDFpZGVhcy5jeg==\n"].map { |i| Base64.decode64(i) }

  # files
  s.files = `git ls-files`.split("\n").reject { |file| file =~ /^vendor\// || file =~ /^gemfiles\// }
  s.require_paths = ["lib"]

  s.rdoc_options = '--include=examples --main README.md'
  s.extra_rdoc_files = ["README.md"] + Dir.glob("docs/*")

  # Dependencies
  s.add_dependency "eventmachine"
  s.add_dependency "amq-client",   "~> 0.8.6"
  s.add_dependency "amq-protocol", "~> 0.8.4"

  begin
    require "changelog"
    s.post_install_message = CHANGELOG.new.version_changes
  rescue LoadError
    # warn "You have to have changelog gem installed for post install message"
  end

  # RubyForge
  s.rubyforge_project = "amqp"
end
