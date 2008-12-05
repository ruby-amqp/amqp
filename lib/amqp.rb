module AMQP
  VERSION = '0.5.9'

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
    attr_reader :conn, :closing
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
      :timeout => nil,

      # logging
      :logging => false
    }
  end

  def self.start *args, &blk
    EM.run{
      @conn ||= connect *args
      @conn.callback(&blk) if blk
      @conn
    }
  end

  class << self
    alias :run :start
  end
  
  def self.stop
    if @conn
      @closing = true
      @conn.close{
        yield if block_given?
        @conn = nil
      }
      @closing = false
    end
  end
end
