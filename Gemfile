# encoding: utf-8

gem "eventmachine"
gem "json" if RUBY_VERSION < "1.9" || ARGV.first == "install"

gem "amq-client",   :git => "git://github.com/ruby-amqp/amq-client.git"
gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git"

group(:test) do
  gem "rspec", ">=2.0.0"
end
