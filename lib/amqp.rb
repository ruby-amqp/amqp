module AMQP
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
    attr_reader :stopping
  end

  def self.settings
    @settings ||= {
      :user => 'guest',
      :pass => 'guest',
      :vhost => '/'
    }
  end

  def self.start *args
    @conn ||= Client.connect *args
  end
  
  def self.stop stop_reactor = true, &on_stop
    if @conn
      @conn.callback{ |c|
        if c.channels.keys.any?
          c.channels.each do |_, mq|
            mq.close
          end
        else
          c.close
        end
      }
      @on_stop = proc{
        @conn = nil
        on_stop.call if on_stop
        EM.stop_event_loop if stop_reactor
      }
    end
  end
  
  def self.stopped
    @on_stop.call if @on_stop
    @on_stop = nil
  end
end