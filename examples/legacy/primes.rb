#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))
require 'amqp'

# check MAX numbers for prime-ness
MAX = 1000

# logging
def log(*args)
  p args
end

# spawn workers
workers = ARGV[0] ? (Integer(ARGV[0]) rescue 1) : 1
AMQP.fork(workers) do # TODO: AMQP.fork isn't implemented and I'm not sure if it should be implemented, it looks pretty damn ugly.
  log AMQP::Channel.id, :started

  class Fixnum
    def prime?
      ('1' * self) !~ /^1?$|^(11+?)\1+$/
    end
  end

  class PrimeChecker
    def is_prime? number
      log "prime checker #{AMQP::Channel.id}", :prime?, number
      number.prime?
    end
  end

  # This is the server part of RPC.
  # Everything we'll call on the client part will be actually
  # marshalled and published to a queue which the server part
  # consumes and executes.
  AMQP::Channel.new.rpc('prime checker', PrimeChecker.new)

end

# use workers to check which numbers are prime
AMQP.start(:host => 'localhost') do |connection|

  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close {
      EM.stop { exit }
    }
  end

  prime_checker = AMQP::Channel.new.rpc('prime checker')

  (10_000...(10_000 + MAX)).each do |num|
    log :checking, num

    prime_checker.is_prime?(num) { |is_prime|
      log :prime?, num, is_prime
      (@primes ||= []) << num if is_prime

      if (@responses = (@responses || 0) + 1) == MAX
        log :primes=, @primes
        show_stopper.call
      end
    }
  end

  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper

  EM.add_timer(5, show_stopper)
end
