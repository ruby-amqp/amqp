---
title: "Connecting to the broker, integrating amqp gem with Ruby on Rails, Sinatra and Web apps"
layout: article
---

## About this guide

This guide covers connection to an AMQP broker from standalone and Web
applications, connection error handling, authentication failure handling
and related issues.

This work is licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative
Commons Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
Github](https://github.com/ruby-amqp/rubyamqp.info).

## Which versions of the amqp gem does this guide cover?

This guide covers Ruby amqp gem 1.7.0 and later versions.


## Terminology

In this guide we define a ‘standalone application’ as an application
that does not run on a Web server like Unicorn or Passenger. The key
difference is that these applications control the main Ruby VM thread
and often use it to run the <span class="highlight">EventMachine</span>
event loop. When the amqp gem is used in a Web application, the main
thread is occupied by the Web application server and the code required
to establish a connection to an AMQP broker needs to be a little bit
different.

## Two ways to specify connection parameters

Connection parameters (host, port, username, vhost and so on) can be
passed in two forms:

 * As a hash
 * As a connection URI string (à la JDBC)

### Using a hash

Hash options that the amqp gem will recognize are

 * :host
 * :port
 * :username (aliased as :user)
 * :password (aliased as :pass)
 * :vhost
 * :ssl
 * :timeout (in seconds)
 * :heartbeat (in seconds), 0 means no heartbeat
 * :frame_max

#### Default parameters

Default connection parameters are

``` ruby
{
  :host      => "127.0.0.1",
  :port      => 5672,
  :user      => "guest",
  :pass      => "guest",
  :vhost     => "/",
  :ssl       => false,
  :heartbeat => 0,
  :frame_max => 131072
}
```

### Using connection strings

It is convenient to be able to specify the AMQP connection parameters as
a URI string, and various “amqp” URI schemes exist. Unfortunately, there
is no standard for these URIs, so while the schemes share the same basic
idea, they differ in some details. This implementation aims to encourage
URIs that work as widely as possible.

Here are some examples:

* "amqp://dev.rabbitmq.com"
* "amqp://dev.rabbitmq.com:5672"
* "amqp://guest:guest@dev.rabbitmq.com:5672"
* "amqp://hedgehog:t0ps3kr3t@hub.megacorp.internal/production"
* "amqps://hub.megacorp.internal/%2Fvault"

The URI scheme should be “amqp”, or “amqps” if SSL is required.

The host, port, username and password are represented in the authority
component of the URI in the same way as in http URIs.

The vhost is obtained from the first segment of the path, with the
leading slash removed. The path should contain only a single segment
(i.e, the only slash in it should be the leading one). If the vhost is
to include slashes or other reserved URI characters, these should be
percent-escaped.

Here are some examples that demonstrate how
`AMQP::Client.parse_connection_uri` parses out the vhost
from connection URIs:


```
"amqp://dev.rabbitmq.com"            # => vhost is nil, so default ("/") will be used
"amqp://dev.rabbitmq.com/"           # => vhost is an empty string
"amqp://dev.rabbitmq.com/%2Fvault"   # => vhost is "/vault"
"amqp://dev.rabbitmq.com/production" # => vhost is "production"
"amqp://dev.rabbitmq.com/a.b.c"      # => vhost is "a.b.c"
"amqp://dev.rabbitmq.com/foo/bar"    # => ArgumentError
```

## Starting the event loop and connecting in standalone applications

### EventMachine event loop

The amqp gem uses [EventMachine](http://rubyeventmachine.com) under the
hood and needs an EventMachine event loop to be running in order to
connect to an AMQP broker or to send any data. This means that before
connecting to an AMQP broker, we need to *start the EventMachine
reactor* (get the event loop going). Here is how to do it:

``` ruby
require "amqp"

EventMachine.run do
  # ...
end
```

[EventMachine.run](http://eventmachine.rubyforge.org/EventMachine.html#M000461)
will block the current thread until the event loop is stopped.
Standalone applications often can afford to start the event loop on the
main thread. If you have no experience with threading, this is a
recommended way to proceed.

### Using AMQP.connect with a block

Once the event loop is running, the `AMQP.connect` method
will attempt to connect to the broker. It can be used in two ways. Here
is the first one:

``` ruby
require "amqp"

EventMachine.run do
  # using AMQP.connect with a block
  AMQP.connect(:host => "localhost") do |client|
    # connection is open and ready to be used
  end
end
```

`AMQP.connect` takes a block that will be executed as soon
as the AMQP connection is open. In order for a connection to be opened a
TCP connection has to be set up, authentication has to succeed, and the
broker and client need to complete negotiation of connection parameters
like max frame size.

### Using AMQP.connect without a callback

An alternative way of connecting is this:

``` ruby
require "amqp"

EventMachine.run do
  # using AMQP.connect with a block
  client = AMQP.connect(:host => "hub.megacorp.internal", :username => "hedgehog", :password => "t0ps3kr3t")
  # connection is not yet open, however, amqp gem will delay channel
  # operations until after the connection is open. Bear in mind that
  # amqp gem cannot solve every possible race condition so be careful
end
```

If you do not need to assign the returned value to a variable, then the
“block version” is recommended because it eliminates issues that may
arise from attempts to use a connection object that is not fully opened.
For example, handling of authentication failures is simpler with the
block version, as we will see in the following sections.

### Using AMQP.start

EventMachine.run and `AMQP.connect` with a block is such a
common combination that the amqp gem provides a shortcut:

``` ruby
require "amqp"

AMQP.start("amqp://dev.rabbitmq.com:5672") do |client|
  # connection is open and ready to be used
end
```

As these examples demonstrate, `AMQP.connect` and
`AMQP.start` accept either a Hash of connection options or
a connection URI string.

See the reference documentation for each method to learn all of the
options that they accept and what the default values are.

### On Thread#sleep use

When not passing a block to `AMQP.connect`, it is tempting
to “give the connection some time to become established” by using
`Thread#sleep`. Unless you are running the event loop in a separate
thread, please do not do this. `Thread#sleep` blocks the calling thread
so that if the event loop is running in the current thread, blocking the
thread *will also block the event loop*. **When the event loop is
blocked, no data is sent or received, so the connection does not
proceed.**

### Detecting TCP connection failures

When applications connect to the broker, they need to handle
connection failures. Networks are not 100 reliable and even with
modern system configuration tools, like
[Chef](http://http://www.opscode.com/chef) or
[Puppet](http://http://www.puppetlabs.com), misconfigurations can
happen. Also, the broker might be down for some reason. Ideally, error
detection should happen as early as possible. There are two ways of
detecting TCP connection failure, the first one is to catch an
exception:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"


puts "=> TCP connection failure handling with a rescue statement"
puts

connection_settings = {
  :port     => 9689,
  :vhost    => "/amq_client_testbed",
  :user     => "amq_client_gem",
  :password => "amq_client_gem_password",
  :timeout  => 0.3
}

begin
  AMQP.start(connection_settings) do |connection, open_ok|
    raise "This should not be reachable"
  end
rescue AMQP::TCPConnectionFailed => e
  puts "Caught AMQP::TCPConnectionFailed => TCP connection failed, as expected."
end
```

`AMQP.connect` (and `AMQP.start`) will raise
`AMQP::TCPConnectionFailed` if the connection fails. Code that catches
the error can write to a log about the issue or use retry to execute
the begin block one more time. Because initial connection failures are
due to misconfiguration or network outage, reconnection to the same
endpoint (hostname, port, vhost combination) will result in the same
error over and over again.

An alternative way of handling connection failure is with an _errback_
(a callback for a specific kind of error):

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

puts "=> TCP connection failure handling with a callback"
puts

handler             = Proc.new { |settings| puts "Failed to connect, as expected"; EM.stop }
connection_settings = {
  :port     => 9689,
  :vhost    => "/amq_client_testbed",
  :user     => "amq_client_gem",
  :password => "amq_client_gem_password",
  :timeout  => 0.3,
  :on_tcp_connection_failure => handler
}


AMQP.start(connection_settings) do |connection, open_ok|
  raise "This should not be reachable"
end
```

the <span class="note">:on_tcp_connection_failure</span> option
accepts any object that responds to `#call`.

If you connect to the broker from code in a class (as opposed to
top-level scope in a script), `Object#method` can be used to pass an
object method as a handler instead of a Proc.

TBD: provide an example


### Detecting authentication failures

A connection may also fail due to authentication failure. Handling
authentication failure is very similar to handling an initial TCP
connection failure:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

puts "=> Authentication failure handling with a callback"
puts

handler             = Proc.new { |settings| puts "Failed to connect, as expected"; EM.stop }
connection_settings = {
  :port     => 5672,
  :vhost    => "/amq_client_testbed",
  :user     => "amq_client_gem",
  :password => "amq_client_gem_password_that_is_incorrect #{Time.now.to_i}",
  :timeout        => 0.3,
  :on_tcp_connection_failure => handler,
  :on_possible_authentication_failure => Proc.new { |settings|
                                            puts "Authentication failed, as expected, settings are: #{settings.inspect}"

                                            EM.stop
                                          }
}

AMQP.start(connection_settings) do |connection, open_ok|
  raise "This should not be reachable"
end\</pre>

default handler raises `AMQP::PossibleAuthenticationFailureError`:
```

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

puts "=> Authentication failure handling with a rescue block"
puts

handler             = Proc.new { |settings| puts "Failed to connect, as expected"; EM.stop }
connection_settings = {
  :port     => 5672,
  :vhost    => "/amq_client_testbed",
  :user     => "amq_client_gem",
  :password => "amq_client_gem_password_that_is_incorrect #{Time.now.to_i}",
  :timeout        => 0.3,
  :on_tcp_connection_failure => handler
}


begin
  AMQP.start(connection_settings) do |connection, open_ok|
    raise "This should not be reachable"
  end
rescue AMQP::PossibleAuthenticationFailureError => afe
  puts "Authentication failed, as expected, caught #{afe.inspect}"
  EventMachine.stop if EventMachine.reactor_running?
end
```

In case you are wondering why the callback name has "possible" in it,
[AMQP 0.9.1
spec](https://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf) requires
broker implementations to simply close the TCP connection without
sending any more data when an exception, such as authentication
failure, occurs before the AMQP connection is open. In practice,
however, when a broker closes a TCP connection after a successful TCP
connection has been established but before an AMQP connection is open,
it means that authentication has failed.

## Starting the event loop and connecting in Web applications (Ruby on Rails, Sinatra, Merb, Rack)

Web applications are different from standalone applications in that
the main thread is occupied by a Web/application server like Unicorn
or Thin, so you need to start the EventMachine reactor before you
attempt to use `AMQP.connect`. In a Ruby on Rails
application, probably the best place for this is in the initializer
(like `config/initializers/amqp.rb`). For Merb applications it is <span
class="note">config/init.rb</span>. For Sinatra and pure Rack
applications, place it next to the other configuration code.

Next, we are going to discuss issues specific to particular Web servers.

### Using Ruby amqp gem with Unicorn

#### Unicorn is a pre-forking server

[Unicorn](http://unicorn.bogomips.org) is a pre-forking server. That
means it forks worker processes that serve HTTP requests. The
"[ork(2)](http://en.wikipedia.org/wiki/Fork_(operating_system)) system
call has several gotchas associated with it, two of which affect
EventMachine and the [Ruby amqp
gem](http://github.com/ruby-amqp/amqp):

 * Unintentional file descriptor sharing
 * The fact that a [forked child process only inherits one thread](http://bit.ly/fork-and-threads) and therefore the EventMachine thread is not inherited

To avoid both problems, start the EventMachine reactor and AMQP
connection *after* the master process forks workers. The master
Unicorn process never serves HTTP requests and usually does not need
to hold an AMQP connection. Next, let us see how to spin up the
EventMachine reactor and connect to the broker after Unicorn forks a
worker.


#### Starting the EventMachine reactor and connecting to the broker after Unicorn forks worker processes

Unicorn lets you specify a configuration file to use. In that file you define a callback that Unicorn runs after it forks worker process(es):

``` ruby
ENV["FORKING"] = "true"

listen 3000

worker_processes 1
timeout          30

preload_app true


after_fork do |server, worker|
  require "amqp"

  # the following is *required* for Rails + "preload_app true",
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection


  t = Thread.new { AMQP.start }
  sleep(1.0)

  EventMachine.next_tick do
    AMQP.channel ||= AMQP::Channel.new(AMQP.connection)
    AMQP.channel.queue("amqpgem.examples.rails23.warmup", :durable => true)

    3.times do |i|
      puts "[after_fork/amqp] Publishing a warmup message ##{i}"

      AMQP.channel.default_exchange.publish("A warmup message #{i} from #{Time.now.strftime('H:M:S
m/b/%Y’)}“, :routing_key => ”amqpgem.examples.rails23.warmup“)
 end
 end
end
```

In the example above we start the EventMachine reactor in a separate
thread, block the current thread for 1 second to let the event loop spin
up and then connect to the AMQP broker on the next event loop tick.
Publishing several warmup messages on boot is a good idea because it
allows the early detection of issues that forking may cause.

Note that a configuration file can easily be used in development
environments because, other than the fact that Unicorn runs in the
foreground, it gives you exactly the same application boot behavior as
in QA and production environments.

An [example Ruby on Rails application that uses the Ruby amqp gem and
Unicorn](http://bit.ly/ruby-amqp-gem-example-with-ruby-on-rails-and-unicorn)
is available on GitHub.

### Using the Ruby amqp gem with Passenger

[Phusion Passenger](http://www.modrails.com) is also a pre-forking
server, and just as with Unicorn, the EventMachine reactor and AMQP
connection should be started **after** it forks worker processes. The
Passenger documentation has [a
section](http://bit.ly/passenger-forking-gotchas) that explains how to
avoid problems related to the behavior of the fork(2) system call,
namely:

 * Unintentional file descriptor sharing
 * The fact that a [forked child process only inherits one thread](http://bit.ly/fork-and-threads) and therefore the EventMachine thread is not inherited

#### Using an event handler to spawn one amqp connection per worker

Passenger provides a hook that you should use for spawning AMQP
connections:

``` ruby
if defined?(PhusionPassenger) # otherwise it breaks rake commands if you put this in an initializer
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
       # We’re in a smart spawning mode
       # Now is a good time to connect to the broker
    end
  end
end
```

Basically, the recommended default smart spawn mode works exactly the
same as in Unicorn (with all of the same common pitfalls). An [example
application](http://bit.ly/ruby-amqp-gem-example-with-ruby-on-rails-and-passenger)
is available on github.

### Using the Ruby amqp gem with Thin and Goliath

#### Thin and Goliath start the EventMachine reactor for you, but there
is a little nuance.

If you use [Thin](http://code.macournoyer.com/thin/)
or [Goliath](https://github.com/postrank-labs/goliath/), you are all set
because those two servers use EventMachine under the hood. There is no
need to start the EventMachine reactor. However, depending on the
application server, its version, the version of the framework and Rack
middleware being used, EventMachine reactor start may be slightly
delayed. To overcome this potential difficulty, use
`EventMachine.next_tick` to delay connection until after the reactor is
actually running:

``` ruby
EventMachine.next_tick { AMQP.connect(…) }
```

So, in case the EventMachine reactor is not yet running on
server/application boot, the connection will not fail but will instead
wait for the reactor to start. Thin and Goliath are not pre-forking
servers so there is no need to re-establish the connection as you do
with Unicorn and Passenger.

## If it just does not work: troubleshooting

If you have read this guide and your issue is still unresolved, check
our [Troubleshooting guide](/articles/troubleshooting/) before asking on
the mailing list.

## What to read next

 * [Working With Queues](/articles/working_with_queues/). This guide
focuses on features that consumer applications use heavily.\
 * [Working With Exchanges](/articles/working_with_exchanges/). This
guide focuses on features that producer applications use heavily.
 * [rror Handling & Recovery](/articles/error_handling/). This guide
explains how to handle protocol errors, network failures and other
things that may go wrong in real world projects.
 * [Using TLS (SSL)](/articles/connection_encryption_with_tls/) (if
you want to use an SSL encrypted connection to the broker)
