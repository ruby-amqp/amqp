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


if RUBY_VERSION == "1.8.7"
  module ArrayExtensions
    def sample
      self.choice
    end # sample
  end

  class Array
    include ArrayExtensions
  end
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

# Returns AMQP Frame::Header frame that contains Protocol::Header header
# with (pre-)defined accessors set.
def test_header opts = {}
  AMQP::Frame::Header.new(
      AMQP::Protocol::Header.new(
          opts[:klass] || AMQP::Protocol::Test,
          opts[:size] || 4,
          opts[:weight] || 2,
          opts[:properties] || {:delivery_mode => 1}))
end

# Returns AMQP Frame::Method frame that contains Protocol::Basic::Deliver
# with (pre-)defined accessors set.
def test_method_deliver opts = {}
  AMQP::Frame::Method.new(
      AMQP::Protocol::Basic::Deliver.new(
          :consumer_tag => opts[:consumer_tag] || 'test_consumer'))
end

require "stringio"

def capture_stdout(&block)
  $stdout = StringIO.new
  block.call
  $stdout.rewind
  result = $stdout.read
  $stdout = STDOUT
  return result
end

def capture_stderr(&block)
  $stderr = StringIO.new
  block.call
  $stderr.rewind
  result = $stderr.read
  $stderr = STDOUT
  return result
end
