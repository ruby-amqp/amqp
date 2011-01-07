# encoding: utf-8

begin
  require 'eventmachine'
rescue LoadError
  require 'rubygems'
  require 'eventmachine'
end

require 'ext/emfork'
