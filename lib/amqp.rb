module AMQP
  VERSION = '0.5.5'

  DIR = File.expand_path(File.dirname(File.expand_path(__FILE__)))
  $:.unshift DIR
  
  require 'ext/em'
  require 'ext/blankslate'
  
  %w[ buffer spec protocol frame client ].each do |file|
    require "amqp/#{file}"
  end

  class << self
    @logging = false
    attr_accessor :logging
    attr_reader :conn
    alias :connection :conn
  end

  def self.connect *args
    Client.connect *args
  end

  def self.settings
    @settings ||= {
      # server address
      :host => '127.0.0.1',
      :port => PORT,

      # login details
      :user => 'guest',
      :pass => 'guest',
      :vhost => '/',

      # connection timeout
      :timeout => 3.0,

      # logging
      :logging => false
    }
  end

  def self.start *args
    @conn ||= connect *args
  end
  
  def self.stop
    if @conn
      @conn.close{
        yield if block_given?
        @conn = nil
      }
    end
  end

  def self.run *args
    EM.run{
      AMQP.start(*args).callback{
        yield
      }
    }
  end
end