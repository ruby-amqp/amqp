# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "mq"
require "bacon"
require "em-spec/bacon"

# Notes about Bacon & EM-spec
# - Subsequent describe blocks don't work.
# - Bacon doesn't support any kind of pending specs.
# - Bacon doesn't support before(:all) hook (see bellow).
EM.spec_backend = EventMachine::Spec::Bacon

# Usage with tracer:
# 1) Start tracer on a PORT_NUMBER
# 2) ruby spec/sync_async_spec.rb amqp://localhost:PORT_NUMBER
if ARGV.first && ARGV.first.match(/^amqps?:/)
  amqp_url = ARGV.first
  puts "Using AMQP URL #{amqp_url}"
else
  amqp_url = "amqp://localhost"
end

# Bacon doesn't seem to have some global before hook
Bacon::Context.class_eval do
  alias_method :__initialize__, :initialize

  # Let's use Module#define_method, so we can
  # access local variables defined in parent scopes.
  define_method(:initialize) do |*args, &block|
    __initialize__(*args, &block)

    # There's no support for before(:all), so we just
    # save whatever AMQP.connect returns (we suppose
    # it isn't nil) and use value = value || connect().
    self.before do
      @connected ||= AMQP.connect(amqp_url)
    end
  end
end
