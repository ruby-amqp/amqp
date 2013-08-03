# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'bundler'
Bundler.setup(:default, :test)

require "amqp"
require "evented-spec"
require "effin_utf8"
require "multi_json"

puts "Using Ruby #{RUBY_VERSION} and amq-protocol #{AMQ::Protocol::VERSION}"


amqp_config = File.dirname(__FILE__) + '/amqp.yml'

port = if ENV["TRACER"]
         5673
       else
         5672
       end

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
  AMQP_OPTS = {:host => 'localhost', :port => port}
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
end


EventMachine.kqueue = true if EventMachine.kqueue?
EventMachine.epoll  = true if EventMachine.epoll?


module RabbitMQ
  module Control
    def rabbitmq_pid
      $1.to_i if `rabbitmqctl status` =~ /\{pid,(\d+)\}/
    end

    def start_rabbitmq(delay = 1.0)
      # this is Homebrew-specific :(
      `rabbitmq-server > /dev/null 2>&1 &`; sleep(delay)
    end

    def stop_rabbitmq(pid = rabbitmq_pid, delay = 1.0)
      `rabbitmqctl stop`; sleep(delay)
    end

    def kill_rabbitmq(pid = rabbitmq_pid, delay = 1.0)
      # tango is down, tango is down!
      Process.kill("KILL", pid); sleep(delay)
    end
  end
end


module PlatformDetection
  def mri?
    !defined?(RUBY_ENGINE) || (defined?(RUBY_ENGINE) && ("ruby" == RUBY_ENGINE))
  end

  def rubinius?
    defined?(RUBY_ENGINE) && (RUBY_ENGINE == 'rbx')
  end
end
