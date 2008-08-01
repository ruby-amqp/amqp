module AMQP
  VERSION = '0.5.3'

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
  end

  def self.connect *args
    Client.connect *args
  end

  def self.settings
    @settings ||= {
      :user => 'guest',
      :pass => 'guest',
      :vhost => '/',
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
end