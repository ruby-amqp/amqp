# -*- coding: utf-8 -*-

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'bundler'
Bundler.setup
Bundler.require :default, :test

require "amqp"
require "evented-spec"

# See https://gist.github.com/892414
RSpec::Core::Example.send(:include, Module.new {
  def self.included(base)
    base.class_eval do
      alias_method :__finish__, :finish
      remove_method :finish
    end
  end

  attr_reader :not_implemented_error
  def from_not_implemented_error?
    !! @not_implemented_error
  end

  def finish(reporter)
    if @exception.is_a?(NotImplementedError)
      @not_implemented_error = @exception
      message = "#{@exception.message} (from #{@exception.backtrace[0]})"
      self.metadata[:pending] = true
      @pending_declared_in_example = message
      @exception = nil
    end

    __finish__(reporter)
  end
})

RSpec::Core::Formatters::BaseTextFormatter.send(:include, Module.new {
  def self.included(base)
    base.class_eval do
      remove_method :dump_pending
      remove_method :dump_backtrace
    end
  end

  def dump_pending
    unless pending_examples.empty?
      output.puts
      output.puts "Pending:"
      pending_examples.each do |pending_example|
        output.puts yellow("  #{pending_example.full_description}")
        output.puts grey("    # #{pending_example.execution_result[:pending_message]}")
        output.puts grey("    # #{format_caller(pending_example.location)}")
        if pending_example.from_not_implemented_error? && RSpec.configuration.backtrace_clean_patterns.empty?
          dump_backtrace(pending_example, pending_example.not_implemented_error.backtrace)
        end
      end
    end
  end

  def dump_backtrace(example, backtrace = example.execution_result[:exception].backtrace)
    format_backtrace(backtrace, example).each do |backtrace_info|
      output.puts grey("#{long_padding}# #{backtrace_info}")
    end
  end
})

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
