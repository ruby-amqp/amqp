# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'bundler'
Bundler.setup
Bundler.require :default, :test

require "mq"

# EM.spec_backend = EventMachine::Spec::Rspec

# Usage with tracer:
# 1) Start tracer on a PORT_NUMBER
# 2) ruby spec/sync_async_spec.rb amqp://localhost:PORT_NUMBER
# if ARGV.first && ARGV.first.match(/^amqps?:/)
#   amqp_url = ARGV.first
#   puts "Using AMQP URL #{amqp_url}"
# else
#   amqp_url = "amqp://localhost"
# end

# Shorthand for mocking subject's instance variable
def subject_mock(name, as_null = false)
  mock = mock(name)
  mock.as_null_object if as_null
  subject.instance_variable_set(name.to_sym, mock)
  mock
end

# Returns Header that should be correctly parsed
def basic_header opts = {}
  AMQP::Frame::Header.new(
      AMQP::Protocol::Header.new(
          AMQP::Protocol::Basic, :priority => 1), opts[:channel] || 0)
end


