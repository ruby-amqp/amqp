---
title: "Error handling and recovery"
layout: article
---

## About this guide

Development of a robust application, be it message publisher or message
consumer, involves dealing with multiple kinds of failures: protocol
exceptions, network failures, broker failures and so on. Correct error
handling and recovery is not easy. This guide explains how the amqp gem
helps you in dealing with issues like

 * Initial RabbitMQ connection failures
 * Network connection interruption
 * Connection-level exceptions
 * Channel-level exceptions
 * RabbitMQ node failure
 * TLS (SSL) related issues

as well as

 * How to recover after a network failure
 * What is automatic recovery mode and when you should/should not use
it

This work is licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative
Commons Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
Github](https://github.com/ruby-amqp/rubyamqp.info).

## Covered versions

This guide covers Ruby amqp gem 1.7.0 and later versions.

## Code examples

There are several
[examples](https://github.com/ruby-amqp/amqp/tree/master/examples/error_handling)
in the git repository dedicated to the topic of error handling and
recovery. Feel free to contribute new examples.

### Initial broker connection failures

When applications connect to the broker, they need to handle connection
failures. Networks are not
100% reliable, even with modern system configuration tools like Chef or Puppet misconfigurations happen and the broker might also be down. Error detection should happen as early as possible. There are two ways of detecting TCP connection failure, the first one is to catch an exception:

``` ruby
begin
  AMQP.start(connection_settings) do |connection, open_ok|
    raise "This should not be reachable"
  end
rescue AMQP::TCPConnectionFailed => e
  puts "Caught AMQP::TCPConnectionFailed => TCP connection failed, as expected."
end
```

Full example:

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
  :timeout        => 0.3
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
`AMQP::TCPConnectionFailed` if a connection fails. Code that catches
it can write to a log about the issue or use retry to execute the
begin block one more time. Because initial connection failures are due
to misconfiguration or network outage, reconnection to the same
endpoint (hostname, port, vhost combination) will result in the same
issue over and over. TBD: failover, connection to the cluster.

An alternative way of handling connection failure is with an errback
(a callback for specific kind of error):

``` ruby
handler             = Proc.new { |settings| puts "Failed to connect, as expected"; EventMachine.stop }
connection_settings = {
  :port     => 9689,
  :vhost    => "/amq_client_testbed",
  :user     => "amq_client_gem",
  :password => "amq_client_gem_password",
  :timeout        => 0.3,
  :on_tcp_connection_failure => handler
}
```

Full example:

``` ruby
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
  :timeout        => 0.3,
  :on_tcp_connection_failure => handler
}


AMQP.start(connection_settings) do |connection, open_ok|
  raise "This should not be reachable"
end
```

`:on_tcp_connection_failure` option accepts any object that responds to
`#call`.

If you connect to the broker from code in a class (as opposed to
top-level scope in a script), `Object#method` can be used to pass object
method as a handler instead of a Proc.

### Authentication failures

Another reason why a connection may fail is authentication failure.
Handling authentication failure is very similar to handling initial TCP
connection failure:

``` ruby
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
end
```

#### Default handler

default handler raises `AMQP::PossibleAuthenticationFailureError`:

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

In case you are wondering why callback name has "possible” in it: [AMQP
0.9.1 spec](https://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf) requires broker implementations
to simply close TCP connection without sending any more data when an
exception (such as authentication failure) occurs before AMQP connection
is open. In practice, however, when broker closes TCP connection between
successful TCP connection and before AMQP connection is open, it means
that authentication has failed.

## Handling network connection interruptions

Network connectivity issues are a sad fact of life in modern software
systems. Even small products and projects these days consist of multiple
applications, often running on more than one machine. The Ruby amqp gem
detects TCP connection failures and lets you handle them by defining a
callback using
`AMQP::Session#on_tcp_connection_loss`.
That callback will be run when TCP connection fails, and will be passed
two parameters: connection object and settings of the last successful
connection.

``` ruby
    connection.on_tcp_connection_loss do |connection, settings|
      # reconnect in 10 seconds, without enforcement
      connection.reconnect(false, 10)
    end
```

Sometimes it is necessary for other entities in an application to
react to network failures. amqp gem 0.8.0 and later provides a number
of event handlers to make this task easier for developers. This set of
features is known as the "shutdown protocol” (the word "protocol” here
means "API interface” or "behavior”, not network protocol).

`AMQP::Session`, `AMQP::Channel`, `AMQP::Exchange`, `AMQP::Queue` and
`AMQP::Consumer` all implement shutdown protocol and thus
errorhandling API is consistent for all classes, with `AMQP::Session`
and `AMQP::Channel` have a few methods that other entities do not
have.

The Shutdown protocol revolves around two events:

 * Network connection fails
 * Broker closes AMQP connection (or channel)

In this section, we will concentrate on the former. When a network
connection fails, the underlying networking library detects it and runs
a piece of code on `AMQP::Session` to handle it. That, in
turn, propagates this event to channels, channels propagate it to
exchanges and queues, queues propagate it to their consumers (if any).
Each of these entities in the object graph can react to network
interruption by executing application-defined callbacks.

### Shutdown Protocol methods on AMQP::Session

 * `AMQP::Session#on_tcp_connection_loss`
 * `AMQP::Session#on_connection_interruption`

The difference between these methods is that
`AMQP::Session#on_tcp_connection_loss`
is used to define a callback that will be executed **once** when TCP
connection fails. It is possible that reconnection attempts will not
succeed immediately, so there will be subsequent failures. To react to
those, `AMQP::Session#on_connection_interruption` method is used.

The first argument that both of these methods yield to the handler that
your application defines is the connection itself. This is done to make
sure that you can register Ruby objects as handlers, and they do not
have to keep any state around (for example, connection instances):

``` ruby
connection.on_connection_interruption do |conn|
  puts "Connection detected connection interruption"
end

# or

class ConnectionInterruptionHandler

  #
  # API
  #

  def handle(connection)
    # handling logic
  end

end

handler = ConnectionInterruptionHandler.new
connection.on_connection_interruption(&handler.method(:handle))
```

Note that `AMQP::Session#on_connection_interruption`
callback is called **before** this event is propagated to channels,
queues and so on.

Different applications handle connection failures differently. It is
very common to use
`AMQP::Session#reconnect` method to
schedule a reconnection to the same host, or use
`AMQP::Session#reconnect_to` to connect to a different
one.
For some applications it is OK to simply exit and wait to be restarted
at a later point in time, for example, by a process monitoring system
like Nagios or Monit.

### Shutdown Protocol methods on AMQP::Channel

`AMQP::Channel` provides only one method:
`AMQP::Channel#on_connection_interruption`,
that registers a callback similar to the one seen in the previous
section:

``` ruby
channel.on_connection_interruption do |ch|
  puts "Channel #{ch.id} detected connection interruption"
end
```

Note that
`AMQP::Channel#on_connection_interruption`
callback is called **after** this event is propagated to exchanges,
queues and so on. Right after that channel state is reset, except for
error handling/recovery-related callbacks.

<span class="note">
Many applications do not need per-channel network
failure handling.
</span>

### Shutdown Protocol methods on AMQP::Exchange

`AMQP::Exchange` provides only one method:
`AMQP::Exchange#on_connection_interruption`,
that registers a callback similar to the one seen in the previous
section:

``` ruby
exchange.on_connection_interruption do |ex|
  puts "Exchange #{ex.name} detected connection interruption"
end
```

<span class="note">
Many applications do not need per-exchange network
failure handling.
</span>

### Shutdown Protocol methods on AMQP::Queue

`AMQP::Queue` provides only one method:
`AMQP::Queue#on_connection_interruption`,
that registers a callback similar tothe one seen in the previous
section:

``` ruby
queue.on_connection_interruption do |q|
  puts "Queue #{q.name} detected connection interruption"
end
```

Note that AMQP::Queue#on_connection_interruption callback is called
**after** this event is propagated to consumers.

<span class="note">Many applications do not need per-queue network
failure handling.`

### Shutdown Protocol methods on AMQP::Consumer

`AMQP::Consumer` provides only one method:
`AMQP::Consumer#on_connection_interruption`,
that registers a callback similar to the one seen in the previous
section:

``` ruby
consumer.on_connection_interruption do |c|
  puts "Consumer with consumer tag #{c.consumer_tag} detected connection interruption"
end
```

<span class="note">Many applications do not need per-consumer network
failure handling.`

## Recovering from network connection failures

Detecting network connections is nearly useless if an AMQP-based
application cannot recover from them. Recovery is the hard part in
"error handling and recovery”. Fortunately, the recovery process for
many applications follows one simple scheme that the amqp gem can
perform automatically for you.

<span class="note">The recovery process, both manual and automatic,
always begins with re-opening an AMQP connection and then all the
channels on that connection.`

### Manual recovery

Similarly to the Shutdown Protocol, the amqp gem entities implement a
Recovery Protocol. The Recovery Protocol consists of three methods that
connections, channels, queues, consumers and exchanges all implement:

 * `AMQP::Session#before_recovery`
 * `AMQP::Session#auto_recover`
 * `AMQP::Session#after_recovery`

`AMQP::Session#before_recovery` lets application developers register a
callback that will be executed **after TCP connection is re-established
but before AMQP connection is reopened**.
`AMQP::Session#after_recovery` is similar except that the callback is
run **after AMQP connection is reopened**.

`AMQP::Channel`, `AMQP::Queue`, `AMQP::Consumer`, and `AMQP::Exchange`
method's behavior is identical.

Recovery process for AMQP applications usually involves the following
steps:

 1. Re-open AMQP connection.
 2. Once connection is open again, re-open all AMQP channels on that
    connection.
 3. For each channel, re-declare all exchanges.
 4. For each channel, re-declare all queues.
 5. Once queue is declared, for each queue, re-register all bindings.
 6. Once queue is declared, for each queue, re-register all consumers.

### Automatic recovery

Many applications use the same recovery strategy that consists of the
following steps:

 1. Re-open channels.
 2. For each channel, re-declare exchanges (except for predefined ones).
 3. For each channel, re-declare queues.
 4. For each queue, recover all bindings.
 5. For each queue, recover all consumers.

The amqp gem provides a feature known as "automatic recovery” that is
**opt-in** (not opt-out, not used by default) and lets application
developers get the aforementioned recovery strategy by setting one
additional attribute on `AMQP::Channel` instance:

``` ruby
ch = AMQP::Channel.new(connection)
ch.auto_recovery = true
```

A more verbose way to do the same thing:

``` ruby
ch = AMQP::Channel.new(connection, AMQP::Channel.next_channel_id, :auto_recovery => true)
```

Note that if you do not want to pass any options, the second argument
can be left out as well, then it will default to
`AMQP::Channel.next_channel_id`.

To find out whether a channel uses automatic recovery mode or not, use
`AMQP::Channel#auto_recovering?`.

Auto recovery mode can be turned on and off any number of times during
channel life cycle, although a very small percentage of applications
actually do this. Typically you decide what channels should be using
automatic recovery during the application design stage.

Full example (run it, then shut down AMQP broker running on localhost,
then bring it back up and use management tools such as `rabbitmqctl` to
see that queues, bindings and consumers have all recovered):

``` ruby
require "rubygems"
require "amqp" # requires version >= 0.8.0.RC14

puts "=> Example of automatic AMQP channel and queues recovery"
puts
AMQP.start(:host => "localhost") do |connection, open_ok|
  connection.on_error do |ch, connection_close|
    raise connection_close.reply_text
  end

  ch1 = AMQP::Channel.new(connection)
  ch1.auto_recovery = true
  ch1.on_error do |ch, channel_close|
    raise channel_close.reply_text
  end

  if ch1.auto_recovering?
    puts "Channel #{ch1.id} IS auto-recovering"
  end

  connection.on_tcp_connection_loss do |conn, settings|
    puts "[network failure] Trying to reconnect..."
    conn.reconnect(false, 2)
  end


  ch1.queue("amqpgem.examples.queue1", :auto_delete => true).bind("amq.fanout")
  ch1.queue("amqpgem.examples.queue2", :auto_delete => true).bind("amq.fanout")
  ch1.queue("amqpgem.examples.queue3", :auto_delete => true).bind("amq.fanout").subscribe do |metadata, payload|
  end


  show_stopper = Proc.new {
    connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
  }

  Signal.trap "TERM", show_stopper
  Signal.trap "INT",  show_stopper
  EM.add_timer(30, show_stopper)


  puts "Connected, authenticated. To really exercise this example, shut AMQP broker down for a few seconds. If you don't it will exit gracefully in 30 seconds."
end
```

Server-named queues, when recovered automatically, will get **new
server-generated names** to guarantee there are no name collisions.

<span class="note">When in doubt, try using automatic recovery first. If
it is not sufficient for your application, switch to manual recovery
using events and callbacks introduced in the "Manual recovery”
section.
</span>

## Detecting broker failures

AMQP applications see broker failure as TCP connection loss. There is no
reliable way to know whether there is a network problem or a network
peer is down.

## AMQP connection-level exceptions

### Handling connection-level exceptions

Connection-level exceptions are rare and may indicate a serious issue
with a client library or in-flight data corruption. The AMQP 0.9.1
specification mandates that a connection that has errored cannot be used
any more and must be closed. In any case, your application should be
prepared to handle this kind of error. To define a handler, use
`AMQP::Session#on_error` method that
takes a callback and yields two arguments to it when a connection-level
exception happens:

``` ruby
connection.on_error do |conn, connection_close|
  puts "Handling a connection-level exception."
  puts
  puts "AMQP class id : #{connection_close.class_id}"
  puts "AMQP method id: #{connection_close.method_id}"
  puts "Status code   : #{connection_close.reply_code}"
  puts "Error message : #{connection_close.reply_text}"
end
```

Status codes are similar to those of HTTP. For the full list of error
codes and their meaning, consult [AMQP 0.9.1 constants
reference](http://www.rabbitmq.com/amqp-0-9-1-reference.html#constants).

<span class="note">Only one connection-level exception handler can be
defined per connection instance (the one added last replaces previously
added ones).

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  AMQP.connect(:host => '127.0.0.1', :port => 5672) do |connection|
    puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."


    connection.on_error do |conn, connection_close|
      puts <<-ERR
      Handling a connection-level exception.

      AMQP class id : #{connection_close.class_id},
      AMQP method id: #{connection_close.method_id},
      Status code   : #{connection_close.reply_code}
      Error message : #{connection_close.reply_text}
      ERR

      EventMachine.stop
    end

    # send_frame is NOT part of the public API, but it is public for entities like AMQ::Client::Channel
    # and we use it here to trigger a connection-level exception. MK.
    connection.send_frame(AMQ::Protocol::Connection::TuneOk.encode(1000, 1024 * 128 * 1024, 10))
  end
end
```

## Handling graceful broker shutdown

When an AMQP broker is shut down, it properly closes connections first.
To do so, it uses **connection.close** AMQP method. AMQP clients then
need to check if the reply code is equal to 320 (CONNECTION_FORCED) to
distinguish graceful shutdown. With RabbitMQ, when broker is stopped
using

``` bash
rabbitmqctl stop
```

reply_text will be set to

```
CONNECTION_FORCED - broker forced connection closure with reason
‘shutdown’
```

Each application chooses how to handle graceful broker shutdowns
individually, so **amqp gem’s automatic reconnection does not cover
graceful broker shutdowns**. Applications that want to reconnect when
broker is stopped can use
`AMQP::Session#periodically_reconnect`
like so:

``` ruby
connection.on_error do |conn, connection_close|
  puts "[connection.close] Reply code = #{connection_close.reply_code}, reply text = #{connection_close.reply_text}"
  if connection_close.reply_code == 320
    puts "[connection.close] Setting up a periodic reconnection timer..."
    # every 30 seconds
    conn.periodically_reconnect(30)
  end
end
```

Once AMQP connection is re-opened, channels in automatic recovery mode
will recover just like they do after network outages.

## Integrating channel-level exceptions handling with object-oriented Ruby code

Error handling can be easily integrated into object-oriented Ruby code
(in fact, this is highly encouraged). A common technique is to combine
[Object#method](http://rubydoc.info/stdlib/core/1.8.7/Object:method)
and
[Method#to_proc](http://rubydoc.info/stdlib/core/1.8.7/Method:to_proc)
and use object methods as error handlers:

``` ruby
class ConnectionManager

  #
  # API
  #

  def connect(*args, &block)
    @connection = AMQP.connect(*args, &block)

    # combines Object#method and Method#to_proc to use object
    # method as a callback
    @connection.on_error(&method(:on_error))
  end # connect(*args, &block)


  def on_error(connection, connection_close)
    puts "Handling a connection-level exception."
    puts
    puts "AMQP class id : #{connection_close.class_id}"
    puts "AMQP method id: #{connection_close.method_id}"
    puts "Status code   : #{connection_close.reply_code}"
    puts "Error message : #{connection_close.reply_text}"
  end # on_error(connection, connection_close)
end
```

Full example that uses objects:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


class ConnectionManager

  #
  # API
  #

  def connect(*args, &block)
    @connection = AMQP.connect(*args, &block)

    # combines Object#method and Method#to_proc to use object
    # method as a callback
    @connection.on_error(&method(:on_error))
  end # connect(*args, &block)


  def on_error(connection, connection_close)
    puts "Handling a connection-level exception."
    puts
    puts "AMQP class id : #{connection_close.class_id}"
    puts "AMQP method id: #{connection_close.method_id}"
    puts "Status code   : #{connection_close.reply_code}"
    puts "Error message : #{connection_close.reply_text}"
  end # on_error(connection, connection_close)
end

EventMachine.run do
  manager = ConnectionManager.new
  manager.connect(:host => '127.0.0.1', :port => 5672) do |connection|
    puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."

    # send_frame is NOT part of the public API, but it is public for entities like AMQ::Client::Channel
    # and we use it here to trigger a connection-level exception. MK.
    connection.send_frame(AMQ::Protocol::Connection::TuneOk.encode(1000, 1024 * 128 * 1024, 10))
  end

  # shut down after 2 seconds
  EventMachine.add_timer(2) { EventMachine.stop }
end
```


## AMQP channel-level exceptions

### Handling channel-level exceptions

Channel-level exceptions are more common than connection-level ones.
They are handled in a similar manner, by defining a callback with
`AMQP::Channel#on_error` method that
takes a callback and yields two arguments to it when a channel-level
exception happens:

``` ruby
channel.on_error do |ch, channel_close|
  puts "Handling a channel-level exception."
  puts
  puts "AMQP class id : #{channel_close.class_id}"
  puts "AMQP method id: #{channel_close.method_id}"
  puts "Status code   : #{channel_close.reply_code}"
  puts "Error message : #{channel_close.reply_text}"
end
```

Status codes are similar to those of HTTP. For the full list of error
codes and their meaning, consult [AMQP 0.9.1 constants
reference](http://www.rabbitmq.com/amqp-0-9-1-reference.html#constants).

<span class="note">Only one channel-level exception handler can be
defined per channel instance (the one added last replaces previously
added ones).`

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'


puts "=> Queue redeclaration with different attributes results in a channel exception that is handled"
puts
AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    puts "Channel ##{channel.id} is now open!"

    channel.on_error do |ch, channel_close|
      puts <<-ERR
      Handling a channel-level exception.

      AMQP class id : #{channel_close.class_id},
      AMQP method id: #{channel_close.method_id},
      Status code   : #{channel_close.reply_code}
      Error message : #{channel_close.reply_text}
      ERR
    end

    EventMachine.add_timer(0.4) do
      # these two definitions result in a race condition. For sake of this example,
      # however, it does not matter. Whatever definition succeeds first, 2nd one will
      # cause a channel-level exception (because attributes are not identical)
      AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => false) do |queue|
        puts "#{queue.name} is ready to go"
      end

      AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => true) do |queue|
        puts "#{queue.name} is ready to go"
      end
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close { EventMachine.stop }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(2, show_stopper)
end
```

### Integrating channel-level exceptions handling with object-oriented Ruby code

Error handling can be easily integrated into object-oriented Ruby code
(in fact, this is highly encouraged).A common technique is to combine
[Object#method](http://rubydoc.info/stdlib/core/1.8.7/Object:method)
and
[Method#to_proc](http://rubydoc.info/stdlib/core/1.8.7/Method:to_proc)
and use object methods as error handlers. For example of this, see
section on connection-level exceptions above.

<span class="note">
Because channel-level exceptions may be raised
because of multiple unrelated reasons and often indicate
misconfigurations, how they are handled isvery specific to particular
applications. A common strategy is to log an error and then open and use
another channel.
</span>

### Common channel-level exceptions and what they mean

A few channel-level exceptions are common and deserve more attention.

#### 406 Precondition Failed

<dl>

<dt>
Description
</dt>

<dd>
The client requested a method that was not allowed because some
precondition failed.
</dd>

<dt>
What might cause it
</dt>

<dd>
<ul>
<li>
AMQP entity (a queue or exchange) was re-declared with attributes
different from original declaration. Maybe two applications or pieces of
code declare the same entity with different attributes. Note that
different AMQP client libraries historically use slightly different
defaults for entities and this may cause attribute mismatches.
</li>
<li>
`AMQP::Channel#tx_commit` or
`AMQP::Channel#tx_rollback` might be run on a channel
that wasn’t previously made transactional with
`AMQP::Channel#tx_select`
</li>
</ul>
</dd>

<dt>
Example RabbitMQ error message

</dt>

<dd>

<ul>

<li>
PRECONDITION_FAILED - parameters for queue
‘amqpgem.examples.channel_exception’ in vhost ‘/’ not equivalent

</li>

<li>
PRECONDITION_FAILED - channel is not transactional
</li>
</ul>
</dd>
</dl>

#### 405 Resource Locked

<dl>
<dt>
Description
</dt>
<dd>
The client attempted to work with a server entity to which it has no
access because another client is working with it.
</dd>
<dt>
What might cause it
</dt>
<dd>
<ul>
<li>
Multiple applications (or different pieces of
code/threads/processes/routines within a single application) might try
to declare queues with the same name as exclusive.
</li>
<li>
Multiple consumer across multiple or single app might be registered as
exclusive for the same queue.
</li>
</ul>
</dd>
<dt>
Example RabbitMQ error message
</dt>
<dd>
RESOURCE_LOCKED - cannot obtain exclusive access to locked queue
‘amqpgem.examples.queue’ in vhost ‘/’

</dd>
</dl>

#### 403 Access Refused

<dl>
<dt>
Description
</dt>
<dd>
The client attempted to work with a server entity to which it has no
access due to security settings.
</dd>
<dt>
What might cause it
</dt>
<dd>
Application tries to access a queue or exchange it has no permissions
for (or right kind of permissions, for example, write permissions)
</dd>
<dt>
Example RabbitMQ error message
</dt>
<dd>
ACCESS_REFUSED - access to queue ‘amqpgem.examples.channel_exception’
in vhost ‘amqp_gem_testbed’ refused for user ‘amqp_gem_reader’
</dd>
</dl>

## Conclusion

Distributed applications introduce a whole new class of failures
developers need to be aware of. Many of them stem from unreliable
networks. The famous [Fallacies of Distributed
Computing](http://en.wikipedia.org/wiki/Fallacies_of_Distributed_Computing)
list common assumptions software engineers must not make:

 * The network is reliable.
 * Latency is zero.
 * Bandwidth is infinite.
 * The network is secure.
 * Topology doesn’t change.
 * There is one administrator.
 * Transport cost is zero.
 * The network is homogeneous.

Unfortunately, applications that use Ruby and AMQP are not immune to
these problems and developers need to always keep that in mind. This
list is just as relevant today as it was in the 90s.

Ruby amqp gem 0.8.x and later lets applications define handlers that
handle connection-level exceptions, channel-level exceptions and TCP
connection failures. Handling AMQP exceptions and network connection
failures is relatively easy. Re-declaring AMQP instances that the
application works with is where most of the complexity comes from. By
using Ruby objects as error handlers, the declaration of AMQP entities
can be done in one place, making code much easier to understand and
maintain.

amqp gem error and interruption handling is not a copy of RabbitMQ Java
client’s [Shutdown
Protocol](http://www.rabbitmq.com/api-guide.html#shutdown), but they
turn out to be similar with respect to network failures and
connection-level exceptions.
