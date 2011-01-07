# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'bundler'
Bundler.setup
Bundler.require :default, :test

require "mq"

amqp_config = File.dirname(__FILE__) + '/amqp.yml'

if File.exists? amqp_config
  class Hash
    def symbolize_keys
      self.inject({}) do |result, (key, value)|
        new_key = key.is_a?(String) ? key.to_sym : key
        new_value = value.is_a?(Hash) ? value.symbolize_keys : value
        result[new_key] = new_value
        result
      end
    end
  end
  AMQP_OPTS = YAML::load_file(amqp_config).symbolize_keys[:test]
else
  AMQP_OPTS = {:host => 'localhost', :port => 5672}
end

# Shorthand for mocking subject's instance variable
def subject_mock(name, as_null = false)
  mock = mock(name)
  mock.as_null_object if as_null
  subject.instance_variable_set(name.to_sym, mock)
  mock
end

# Returns Header that should be correctly parsed
def basic_header(opts = {})
  AMQP::Frame::Header.new(
      AMQP::Protocol::Header.new(
          AMQP::Protocol::Basic, :priority => 1), opts[:channel] || 0)
end


