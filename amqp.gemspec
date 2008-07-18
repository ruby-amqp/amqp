spec = Gem::Specification.new do |s|
  s.name = 'amqp'
  s.version = '0.5.0'
  s.date = '2008-07-17'
  s.summary = 'AMQP client implementation in Ruby/EventMachine'
  s.email = "amqp@tmm1.net"
  s.homepage = "http://amqp.rubyforge.org/"
  s.description = "AMQP client implementation in Ruby/EventMachine"
  s.has_rdoc = false
  s.authors = ["Aman Gupta"]
  s.files = Dir['{examples,lib,protocol}/**/*.{json,rb,txt,xml}'].map
  s.files += ['README']
end