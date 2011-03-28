# encoding: utf-8

source "http://gemcutter.org"

gem "eventmachine"
gem "json", :platform => :ruby_18
gem "amq-client",   :git => "git://github.com/ruby-amqp/amq-client.git",   :branch => "master"
gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"

group(:development) do
  gem "nake",         :platform => :ruby_19
  gem "contributors", :platform => :ruby_19
end

group(:test) do
  gem "rspec", ">=2.0.0"
  gem "evented-spec", :git => "git://github.com/ruby-amqp/evented-spec.git", :branch => "master"
end
