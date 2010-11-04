$LOAD_PATH << "." unless $LOAD_PATH.include? "." # moronic 1.9.2 breaks things bad

require 'rspec'

#require 'yaml'

def rspec2?
  defined?(RSpec)
end

