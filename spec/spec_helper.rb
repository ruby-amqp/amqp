# -*- coding: utf-8 -*-

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'bundler'
Bundler.setup
Bundler.require :default, :test

require "amqp"

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

#
# Ruby version-specific
#

case RUBY_VERSION
when "1.8.7" then
  module ArrayExtensions
    def sample
      self.choice
    end # sample
  end

  class Array
    include ArrayExtensions
  end
when "1.8.6" then
  raise "Ruby 1.8.6 is not supported. Sorry, pal. Time to move on beyond One True Ruby. Yes, time flies by."
when /^1.9/ then
  puts "Encoding.default_internal was #{Encoding.default_internal || 'not set'}, switching to #{Encoding::UTF_8}"
  Encoding.default_internal = Encoding::UTF_8

  puts "Encoding.default_external was #{Encoding.default_internal || 'not set'}, switching to #{Encoding::UTF_8}"
  Encoding.default_external = Encoding::UTF_8
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
