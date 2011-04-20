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

gem "eventmachine", "~> 0.12.10"
gem "json", :platform => :ruby_18
custom_gem "amq-client",   :git => "git://github.com/ruby-amqp/amq-client.git",   :branch => "master"
custom_gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"

group(:development) do
  gem "yard"
  # yard tags this buddy along
  gem "RedCloth"

  custom_gem "nake",         :platform => :ruby_19
  custom_gem "contributors", :platform => :ruby_19
end

group(:test) do
  gem "rspec", ">=2.5.0"
  custom_gem "evented-spec", :git => "git://github.com/ruby-amqp/evented-spec.git", :branch => "master"
end
