# encoding: utf-8

source "http://gemcutter.org"

gem "eventmachine"
gem "json" if RUBY_VERSION < "1.9" || ARGV.first == "install"
gem "amq-client", :path => "vendor/amq-client"

group(:test) do
  gem "rspec", ">=2.0.0"
end
