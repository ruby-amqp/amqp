module AMQP
  DIR = File.expand_path(File.dirname(File.expand_path(__FILE__)))
  
  $:.unshift DIR
  
  %w[ buffer spec protocol frame client ].each do |file|
    require "amqp/#{file}"
  end

  class << self
    @logging = false
    attr_accessor :logging
  end
end