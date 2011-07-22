# encoding: utf-8

source :rubygems

# Use local clones if possible.
# If you want to use your local copy, just symlink it to vendor.
def custom_gem(name, options = Hash.new)
  local_path = File.expand_path("../vendor/#{name}", __FILE__)
  if File.exist?(local_path)
    gem name, options.merge(:path => local_path).delete_if { |key, _| [:git, :branch].include?(key) }
  else
    gem name, options
  end
end

custom_gem "eventmachine"
# gem "json", :platform => :ruby_18
custom_gem "amq-client",   :git => "git://github.com/ruby-amqp/amq-client.git",   :branch => "master"
custom_gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"

group(:development) do
  gem "yard", ">= 0.7.2"
  # yard tags this buddy along
  gem "RedCloth",  :platform => :mri
  gem "rdiscount", :platform => :ruby
  gem "yajl-ruby", :platform => :ruby

  # To test event loop helper and various Rack apps
  gem "thin",    :platform => :ruby
  gem "unicorn", :platform => :ruby

  gem "changelog"
end

group :test do
  gem "rspec", "~> 2.6.0"
  gem "rake",  "~> 0.9.2"

  custom_gem "evented-spec", :git => "git://github.com/ruby-amqp/evented-spec.git", :branch => "master"
  gem "effin_utf8"

  gem "multi_json"

  gem "json",      :platform => :jruby
  gem "yajl-ruby", :platform => :ruby_18
end
