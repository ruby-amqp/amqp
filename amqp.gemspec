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

  # ruby -rpp -e "pp Dir['{README,{examples,lib,protocol}/**/*.{json,rb,txt,xml}}'].map"
  s.files = ["README",
             "examples/clock.rb",
             "examples/hashtable.rb",
             "examples/pingpong.rb",
             "examples/primes-forked.rb",
             "examples/primes-processes.rb",
             "examples/primes-simple.rb",
             "examples/primes-threaded.rb",
             "examples/primes.rb",
             "examples/simple.rb",
             "examples/stocks.rb",
             "lib/amqp/buffer.rb",
             "lib/amqp/client.rb",
             "lib/amqp/frame.rb",
             "lib/amqp/protocol.rb",
             "lib/amqp/spec.rb",
             "lib/amqp.rb",
             "lib/emfork.rb",
             "lib/mq/exchange.rb",
             "lib/mq/queue.rb",
             "lib/mq/rpc.rb",
             "lib/mq.rb",
             "protocol/amqp-0.8.json",
             "protocol/codegen.rb",
             "protocol/doc.txt",
             "protocol/amqp-0.8.xml"]
end