# encoding: utf-8

source "http://gemcutter.org"

gem "eventmachine"
gem "json" if RUBY_VERSION < "1.9" || ARGV.first == "install"
gem "amq-client", :git => "git://github.com/ruby-amqp/amq-client.git", :branch => "master"

group(:test) do
  gem "rspec", ">=2.0.0"

  gem "amqp-spec", :git => "git://github.com/ruby-amqp/amqp-spec.git", :branch => "master"
end
