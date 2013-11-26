# encoding: utf-8

source "https://rubygems.org"

# Use local clones if possible.
# If you want to use your local copy, just symlink it to vendor.
def custom_gem(name, options = Hash.new)
  local_path = File.expand_path("../vendor/#{name}", __FILE__)
  if File.exist?(local_path)
    puts "Using #{name} from #{local_path}..."
    gem name, options.merge(:path => local_path).delete_if { |key, _| [:git, :branch].include?(key) }
  else
    gem name, options
  end
end

custom_gem "eventmachine", ">= 1.0.0"
custom_gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"

group :development do
  gem "yard", ">= 0.7.2"
  # yard tags this buddy along
  gem "RedCloth",  :platform => :mri

  platform :ruby do
    gem "rdiscount"

    # To test event loop helper and various Rack apps
    gem "thin"
    gem "unicorn"
  end
end

group :test do
  gem "rspec", "~> 2.6.0"
  gem "rake",  "~> 10.0.0"

  custom_gem "evented-spec", :git => "git://github.com/ruby-amqp/evented-spec.git", :branch => "master"
  gem "effin_utf8"

  gem "multi_json"

  gem "json",      :platform => :jruby
  gem "yajl-ruby", :platform => :ruby_18
end
