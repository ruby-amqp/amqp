# -*- coding: utf-8 -*-

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'bundler'
Bundler.setup
Bundler.require :default, :test

require "amqp"
require "evented-spec"



def em_amqp_connect(&block)
  em do
    AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "/amq_client_testbed", :frame_max => 65536, :heartbeat_interval => 1) do |client|
      yield client
    end
  end
end


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

# puts "AMQP_OPTS = #{AMQP_OPTS.inspect}"

#
# Ruby version-specific
#

case RUBY_VERSION
when "1.8.7" then
  class Array
    alias sample choice
  end
when "1.8.6" then
  raise "Ruby 1.8.6 is not supported. Sorry, pal. Time to move on beyond One True Ruby. Yes, time flies by."
when /^1.9/ then
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end
