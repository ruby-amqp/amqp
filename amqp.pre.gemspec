#!/usr/bin/env gem build
# encoding: utf-8

eval(File.read("amqp.gemspec")).tap do |specification|
  specification.version = "#{specification.version}.pre"
end
