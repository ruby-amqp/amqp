# encoding: utf-8

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'amqp'


def log(*args)
  p args
end

# AMQP.logging = true

class HashTable < Hash
  def get(key)
    log 'HashTable', :get, key
    self[key]
  end

  def set(key, value)
    log 'HashTable', :set, key => value
    self[key] = value
  end

  def keys
    log 'HashTable', :keys
    super
  end
end

AMQP.start(:host => 'localhost') do |connection|
  trap(:INT) do
    unless connection.closing?
      connection.close { exit! }
    end
  end

  channel = AMQP::Channel.new(connection)
  server  = channel.rpc('hash table node', HashTable.new)
  client  = channel.rpc('hash table node')

  client.set(:now, time = Time.now)
  client.get(:now) do |res|
    raise "get"
    log 'client', :now => res, :eql? => res == time
  end

  client.set(:one, 1)
  client.keys do |res|
    log 'client', :keys => res
    AMQP.stop { EM.stop }
  end
end
