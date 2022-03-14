---
title: "Testing AMQP applications"
layout: article
---

## About this guide

This guide covers unit testing of amqp-based applications, primarily
using [evented-spec](http://github.com/ruby-amqp/evented-spec).

## Covered versions

This guide covers Ruby amqp gem 1.7.x and [evented-spec gem](http://github.com/ruby-amqp/evented-spec)
0.9.0 and later.

## Rationale

The AMQP 0.9.1 protocol is inherently asynchronous. Testing of asynchronous
code is often more difficult than synchronous code. There are two
approaches to it:

 * Stubbing out a big chunk of the environment
 * Using a "real" environment

The former is risky because your application becomes divorced from the
actual behavior of other applications. The latter approach is more
reliable but at the same time more tedious, because there is a certain
amount of incidental complexity that a "real" environment carries.

However, a lot of this complexity can be eliminated with tools and
libraries. The evented-spec gem is one of those tools. It grew out of
the necessity to test [amqp Ruby gem](http://github.com/ruby-amqp/amqp)
and has proven to be both very powerful and easy to use. This guide
covers the usage of that gem in the context of applications that use the
amqp gem but can also be useful for testing EventMachine and
Cool.io-based applications.

## Using evented-spec

### Setting up

To start using amqp all you need is to include
`EventedSpec::AMQPSpec` module into your context and add
`#done` calls to your examples:

{ gist 1027377 }

### Testing in the Asynchronous Environment

Since we are using callback mechanisms in order to provide asynchrony,
we have to deal with the situation when we expect a response and that
response never comes. The usual solution includes setting a timeout
which makes the given tests fail if they aren’t finished in a timely
manner. When <a class='highlight'>#done</a> is called, your tests
confirm successful ending of specs. Try removing
<a class='highlight'>done</a> from the above example and see what
happens. (spoiler:
<a class='highlight'>EventedSpec::SpecHelper::SpecTimeoutExceededError:
Example timed out</a>)

### The #done method

The <a class='highlight'>#done</a> method call is a hint for
evented-spec to consider the example finished. If this method is not
called, example will be forcefully terminated after a certain period of
time or "time out". This means there are two approaches to testing of
asynchronous code:

* Have timeout value high enough for all operations to finish (for
example, expected number of messages is received).\
 * Call #done when some condition holds true (for example, message
with a specific property or payload is received).

The latter approach is recommended because it makes tests less dependent
on machine-specific throughput or timing. It is very common for
continuous integration environments to use virtual machines that are
significantly less powerful than the machines that developers use, so
timeouts have to be carefully adjusted to work in both settings.

### Default Connection Options and Timeout

It is sometimes desirable to use custom connection settings for your
test environment as well as the default timeout value used. evented-spec
lets you do this:

``` ruby
require 'spec_helper'
require 'evented-spec'

describe "Hello, world! example" do
  include EventedSpec::AMQPSpec

  default_options :vhost => "amqp_testing_vhost"
  default_timeout 1

  it "should pass" do
    done
  end
end
```

Available options are passed to {AMQP.connect} so it is possible to
specify host, port, vhost, username and password arguments that your
test suite needs.

### Lifecycle Callbacks

evented-spec provides various callbacks similar to rspec’s
<a class='highlight'>before(:each)</a> /
<a class='highlight'>after(:each)</a>. They are called
<a class='highlight'>amqp_before</a> and
<a class='highlight'>amqp_after</a> and happen right after connection
is established or before connection is closed. It is a good place to put
your channel initialization routines.

### Full Example

Now that you’re filled in on the theory, it’s time to do something with
all this knowledge. Below is a slightly modified version of one of the
integration specs from the amqp suite. It sets up a default topic
exchange and publishes various messages about sports events:

{ gist 1027478 }

A couple of things to notice: <a class='highlight'>#done</a> is invoked
using an optional callback and optional delay, also instance variables
behavior in hooks is the same as in "normal" rspec hooks.

### Using #delayed

The amqp gem uses [EventMachine](http://eventmachine.rubyforge.org/)
under the hood. If you don’t know about EventMachine, you can read more
about it on the official site. What’s important for us is that you
**cannot use <a class='highlight'>sleep</a> for delays**. Why? Because
all of the spec code is processed directly in the
[reactor](http://en.wikipedia.org/wiki/Reactor_pattern) thread, if you
<a class='highlight'>sleep</a> in that thread, the reactor cannot send
frames. What you need to use instead is the
<a class='highlight'>#delayed</a> method. It takes delay time in
seconds and a callback that it fires once the delay time has elapsed.
Basic usage is either as a <a class='highlight'>sleep</a> replacement or
to ensure a certain order of execution (although, the latter should not
bother you too much). You can also use it to cleanup your environment
after tests if needed.

In the following example, we declare two channels, then declare the same
queue twice with the same name but different options (which raises a
channel-level exception in AMQP):

``` ruby
require 'spec_helper'

describe AMQP do
  include EventedSpec::AMQPSpec
  default_timeout 5


  context "when queue is redeclared with different attributes across two channels" do
    let(:name)              { "amqp-gem.nondurable.queue" }
    let(:options)           {
      { :durable => false, :passive => false }
    }
    let(:different_options) {
      { :durable => true, :passive => false }
    }


    it "should trigger channel-level #on_error callback" do
      @channel = AMQP::Channel.new
      @channel.on_error do |ch, close|
        puts "This should never happen"
      end
      @q1 = @channel.queue(name, options)

      # backwards compatibility, please consider against
      # using global error handlers in your programs!
      AMQP::Channel.on_error do |msg|
        puts "Global handler has fired: #{msg}"
        @global_callback_fired = true
      end

      # Small delays to ensure the order of execution
      delayed(0.1) {
        @other_channel = AMQP::Channel.new
        @other_channel.on_error do |ch, close|
          @callback_fired = true
        end
        puts "other_channel.id = #{@other_channel.id}"
        @q2 = @other_channel.queue(name, different_options)
      }

      delayed(0.3) {
        @q1.delete
        @q2.delete
      }

      done(0.4) {
        @callback_fired.should be_true
        @global_callback_fired.should be_true
        @other_channel.closed?.should be_true
      }
    end
  end
end # describe AMQP
```

If you draw a timeline, various events happen at 0.0s, then at 0.1s,
then at 0.3s and eventually at 0.4s.

### Design For Testability

As the **Integration With Objects** section of the [Getting Started with
Ruby amqp gem and RabbitMQ](/articles/getting_started/) demonstrates,
good object-oriented design often makes it possible to test AMQP
consumers in isolation without connecting to the broker or even starting
the EventMachine event loop. All of the "Design for testability"
practices apply to AMQP application testing.

### Real world Examples

Please refer to the [amqp gem test
suite](https://github.com/ruby-amqp/amqp/tree/master/spec) to see
evented-spec in action.

### How evented-spec Works

When you include the <a class='highlight'>EventedSpec::AMQPSpec</a>
module, <a class='highlight'>#it</a> calls are wrapped in
<a class='highlight'>EventMachine.start</a> and
<a class='highlight'>AMQP.connect</a> calls, so you can start writing
your examples as if you’re connected. Please note that you still need to
open your own channel(s).

## What to read next

There is a lot more to evented-spec than described in this guide.
[evented-spec
documentation](http://rdoc.info/github/ruby-amqp/evented-spec/master)
covers that gem in more detail. For more code examples, see [amqp Ruby
gem test suite](https://github.com/ruby-amqp/amqp/tree/master/spec).
