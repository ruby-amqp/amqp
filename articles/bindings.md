---
title: "Bindings"
layout: article
---

About this guide
----------------

This guide covers bindings in AMQP 0.9.1, what they are, what role they
play and how to accomplish typical operations using the Ruby amqp gem.

This work is licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative
Commons Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
Github](https://github.com/ruby-amqp/rubyamqp.info).

Covered versions
----------------

This guide covers Ruby amqp gem 1.7.0 and later.

Bindings in AMQP 0.9.1
----------------------

Learn more about how bindings fit into the AMQP Model in the [AMQP 0.9.1
Model Explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html) documentation
guide.

What Are AMQP 0.9.1 Bindings
----------------------------

Bindings are rules that exchanges use (among other things) to route
messages to queues. To instruct an exchange E to route messages to a
queue Q, Q has to *be bound* to E. Bindings may have an optional
*routing key* attribute used by some exchange types. The purpose of the
routing key is to selectively match only specific (matching) messages
published to an exchange to the bound queue. In other words, the routing
key acts like a filter.

To draw an analogy:

 * Queue is like your destination in New York city
 * Exchange is like JFK airport
 * Bindings are routes from JFK to your destination. There may be no
way, or more than one way, to reach it

Some exchange types use routing keys while some others do not (routing
messages unconditionally or based on message metadata). If an AMQP
message cannot be routed to any queue (for example, because there are no
bindings for the exchange it was published to), it is either dropped or
returned to the publisher, depending on the message attributes that the
publisher has set.

If an application wants to connect a queue to an exchange, it needs to
*bind* them. The opposite operation is called *unbinding*.

Binding queues to exchanges
---------------------------

In order to receive messages, a queue needs to be bound to at least one
exchange. Most of the time binding is explcit (done by applications). To
bind a queue to an exchange, use { yard\_link AMQP::Queue\#bind } where
the argument passed can be either an { yard\_link AMQP::Exchange }
instance or a string.

``` ruby
queue.bind(exchange) do |bind_ok|
  puts "Just bound #{queue.name} to #{exchange.name}"
end
```

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Binding a queue to an exchange
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange) do |bind_ok|
      puts "Just bound #{queue.name} to #{exchange.name}"
    end

    connection.close {
      EventMachine.stop { exit }
    }
  end
end
```
The same example using a string without a callback:

``` ruby
queue.bind("amq.fanout")
```

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Binding a queue to an exchange
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  exchange_name = "amq.fanout"

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange_name)
    puts "Bound #{queue.name} to #{exchange_name}"

    connection.close {
      EventMachine.stop { exit }
    }
  end
end
```

Unbinding queues from exchanges
-------------------------------

To unbind a queue from an exchange use
`AMQP::Queue\#unbind`:

``` ruby
queue.unbind(exchange)
```

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  channel.on_error do |ch, channel_close|
    raise "Channel-level exception: #{channel_close.reply_text}"
  end

  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange)

    EventMachine.add_timer(0.5) do
      queue.unbind(exchange) do |_|
        puts "Unbound. Shutting down..."

        connection.close { EventMachine.stop }
      end
    end # EventMachine.add_timer
  end # channel.queue
end
```

<span class="note">Trying to unbind a queue from an exchange that the
queue was never bound to will result in a channel-level
exception.</span>

Bindings, Routing and Returned Messages
---------------------------------------

### How AMQP 0.9.1 Brokers Route Messages

After an AMQP message reaches an AMQP broker and before it reaches a
consumer, several things happen:

 * AMQP broker needs to find one or more queues that the message needs
to be routed to, depending on type of exchange
  * AMQP broker puts a copy of the message into each of those queues or
decides to return the message to the publisher
  * AMQP broker pushes message to consumers on those queues or waits for
applications to fetch them on demand

A more in-depth description is this:

 * AMQP broker needs to consult bindings list for the exchange the
message was published to in order to find one or more queues that the
message needs to be routed to (step 1)
 * If there are no suitable queues found during step 1 and the message
was published as mandatory, it is returned to the publisher (step 1b)
 * If there are suitable queues, a *copy* of the message is placed into
each one (step 2)
 * If the message was published as mandatory, but there are no active
consumers for it, it is returned to the publisher (step 2b)
 * If there are active consumers on those queues and the basic.qos
setting permits, message is pushed to those consumers (step 3)

The important thing to take away from this is that messages may or may
not be routed and it is important for applications to handle unroutable
messages.

### Handling of Unroutable Messages

Unroutable messages are either dropped or returned to producers.
Vendor-specific extensions can provide additional ways of handling
unroutable messages: for example, RabbitMQ’s [Alternate Exchanges
extension](http://www.rabbitmq.com/ae.html) makes it possible to route
unroutable messages to another exchange. amqp gem support for it is
documented in the [Vendor-specific Extensions
guide](/articles/broker_specific_extensions/).

The amqp gem provides a way to handle returned messages with the
`AMQP::Exchange#on_return` method:

``` ruby
exchange.on_return do |basic_return, metadata, payload|
  puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
end
```

[Working With Exchanges](/articles/working_with_exchanges/)
documentation guide provides more information on the subject, including
full code examples.
