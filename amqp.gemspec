spec = Gem::Specification.new do |s|
  s.name = 'amqp'
  s.version = '0.5.1'
  s.date = '2008-07-21'
  s.summary = 'AMQP client implementation in Ruby/EventMachine'
  s.email = "amqp@tmm1.net"
  s.homepage = "http://amqp.rubyforge.org/"
  s.description = "AMQP client implementation in Ruby/EventMachine"
  s.has_rdoc = false
  s.authors = ["Aman Gupta"]
  s.add_dependency('eventmachine', '>= 0.12.1')
  s.files = Dir['{examples,lib,protocol}/**/*.{json,rb,txt,xml}'].map
  s.files += ['README']
end