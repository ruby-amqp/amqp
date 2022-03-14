---
title: "Working with queues"
layout: article
---

## About this guide

This guide covers everything related to queues in the AMQP v0.9.1
specification, common usage scenarios and how to accomplish typical
operations using the amqp gem. This work is licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative
Commons Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
Github](https://github.com/ruby-amqp/rubyamqp.info).

## Which versions of the amqp gem does this guide cover?

This guide covers Ruby amqp gem 1.7.0 and later versions.

## Queues in AMQP 0.9.1 - overview

### What are AMQP queues?

<span class="note">Queues</span> store and forward messages to
consumers. They are similar to mailboxes in SMTP. Messages flow from
producing applications to [exchanges](/articles/working_with_exchanges/)
that route them to queues and finally queues deliver the messages to
consumer applications (or consumer applications fetch messages as
needed).

Note that unlike some other messaging protocols/systems, messages are
not delivered directly to queues. They are delivered to exchanges that
route messages to queues using rules known as
<span class="note">bindings</span>.

AMQP 0-9-1 is a programmable protocol, so queues and bindings alike are
declared by applications.

### Concept of bindings

A <span class="note">binding</span> is an association between a queue
and an exchange. Queues must be bound to at least one exchange in order
to receive messages from publishers. Learn more about bindings in the
[Bindings guide](/articles/bindings/).

### Queue attributes

Queues have several attributes associated with them:

 * Name
 * Exclusivity
 * Durability
 * Whether the queue is auto-deleted when no longer used
 * Other metadata (sometimes called <span class="note">X-arguments</span>)

These attributes define how queues can be used, what their life-cycle is
like and other aspects of queue behavior.

The amqp gem represents queues as instances of `AMQP::Queue`.

## Queue names and declaring queues

Every AMQP queue has a name that identifies it. Queue names often
contain several segments separated by a dot “.”, in a similar fashion to
URI path segments being separated by a slash “/”, although almost any
string can represent a segment (with some limitations - see below).

Before a queue can be used, it has to be **declared**. Declaring a queue
will cause it to be created if it does not already exist. The
declaration will have no effect if the queue does already exist and its
attributes are the **same as those in the declaration**. When the
existing queue attributes are not the same as those in the declaration a
channel-level exception is raised. This case is explained later in this
guide.

### Explicitly named queues

Applications may pick queue names or ask the broker to generate a name
for them.

To declare a queue with a particular name, for example, “images.resize”,
pass it to the Queue class constructor:

``` ruby
queue = AMQP::Queue.new(channel, "images.resize", :auto_delete => true)
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a queue with explicitly given name using AMQP::Queue constructor
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  queue   = AMQP::Queue.new(channel, "images.resize", :auto_delete => true)

  puts "#{queue.name} is ready to go."

  connection.close {
    EventMachine.stop { exit }
  }
end
```

### Server-named queues

To ask an AMQP broker to generate a unique queue name for you, pass an
**empty string** as the queue name argument:

``` ruby
AMQP::Queue.new(channel, "", :auto_delete => true) do |queue, declare_ok|
  puts "#{queue.name} is ready to go. AMQP method: #{declare_ok.inspect}"
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a queue with server-generated name using AMQP::Queue constructor
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  AMQP::Queue.new(channel, "", :auto_delete => true) do |queue|
    puts "#{queue.name} is ready to go."

    connection.close {
      EventMachine.stop { exit }
    }
  end
end
```

The amqp gem allows server-named queues to be declared without
callbacks:

``` ruby
queue = AMQP::Queue.new(channel, "", :auto_delete => true)
```

In this case, as soon as the AMQP broker reply (`queue.declare-ok`
AMQP method) arrives, the queue object name will be assigned to the
value that the broker generated. Many AMQP operations require a queue
name, so before an `AMQP::Queue` instance receives its
name, those operations are delayed. This example demonstrates this:

``` ruby
queue = channel.queue("")
queue.bind("builds").subscribe do |metadata, payload|
  # message handling implementation...
end
```

In this example, binding will be performed as soon as the queue has
received its name generated by the broker.

If a particular piece of code relies on the queue name being available
immediately a callback should be used.

### Reserved queue name prefix

Queue names starting with “amq.” are reserved for internal use by the
broker. Attempts to declare a queue with a name that violates this rule
will result in a channel-level exception with reply code 403
(`ACCESS_REFUSED`) and a reply message similar to this:

```
ACCESS_REFUSED - queue name ‘amq.queue’ contains reserved prefix
’amq.**‘
```

### Queue re-declaration with different attributes

When queue declaration attributes are different from those that the
queue already has, a channel-level exception with code 406
(`PRECONDITION_FAILED`) will be raised. The reply text will be similar to
this:

```
PRECONDITION_FAILED - parameters for queue
’amqpgem.examples.channel_exception’ in vhost ‘/’ not equivalent
```

## Queue life-cycle patterns

According to the AMQP 0.9.1 specification, there are two common message
queue life-cycle patterns:

 * Durable message queues that are shared by many consumers and have an
independent existence: i.e. they will continue to exist and collect
messages whether or not there are consumers to receive them.
 * Temporary message queues that are private to one consumer and are
tied to that consumer. When the consumer disconnects, the message queue
is deleted.

There are some variations of these, such as shared message queues that
are deleted when the last of many consumers disconnects.

Let us examine the example of a well-known service like an event
collector (event logger). A logger is usually up and running regardless
of the existence of services that want to log anything at a particular
point in time. Other applications know which queues to use in order to
communicate with the logger and can rely on those queues being available
and able to survive broker restarts. In this case, explicitly named
durable queues are optimal and the coupling that is created between
applications is not an issue.

Another example of a well-known long-lived service is a distributed
metadata/directory/locking server like [Apache
Zookeeper](http://zookeeper.apache.org), [etcd](https://github.com/coreos/etcd) or DNS. Services like
this benefit from using well-known, not server-generated, queue names
and so do any other applications that use them.

A different sort of scenario is in “a cloud setting” when some kind of
worker/instance might start and stop at any time so that other
applications cannot rely on it being available. In this case, it is
possible to use well-known queue names, but a much better solution is to
use server-generated, short-lived queues that are bound to topic or
fanout exchanges in order to receive relevant messages.

Imagine a service that processes an endless stream of events - Twitter
is one example. When traffic increases, development operations may start
additional application instances in the cloud to handle the load. Those
new instances want to subscribe to receive messages to process, but the
rest of the system does not know anything about them and cannot rely on
them being online or try to address them directly. The new instances
process events from a shared stream and are the same as their peers. In
a case like this, there is no reason for message consumers not to use
queue names generated by the broker.

In general, use of explicitly named or server-named queues depends on
the messaging pattern that your application needs.
[Enterprise Integration Patterns](http://www.eaipatterns.com/) discusses
many messaging patterns in depth and the RabbitMQ FAQ also has a section
on [use cases](http://www.rabbitmq.com/faq.html#scenarios).

## Declaring a durable shared queue

To declare a durable shared queue, you pass a queue name that is a
non-blank string and use the `:durable` option:

``` ruby
queue = AMQP::Queue.new(channel, "images.resize", :durable => true)
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a durable shared queue
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  queue   = AMQP::Queue.new(channel, "images.resize", :durable => true)

  connection.close {
    EventMachine.stop { exit }
  }
end
```

the same example rewritten to use `AMQP::Channel#queue`:

``` ruby
channel.queue("images.resize", :durable => true) do |queue, declare_ok|
  puts "#{queue.name} is ready to go."
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a durable shared queue using AMQP::Channel#queue method
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  queue   = channel.queue("images.resize", :durable => true)

  connection.close {
    EventMachine.stop { exit }
  }
end
```

## Declaring a temporary exclusive queue

To declare a server-named, exclusive, auto-deleted queue, pass `""` (an empty
string) as the queue name and use the ](exclusive") and `:auto_delete`
options:

``` ruby
AMQP::Queue.new(channel, "", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
  puts "#{queue.name} is ready to go."
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a temporary exclusive queue
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)

  AMQP::Queue.new(channel, "", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    puts "#{queue.name} is ready to go."

    connection.close {
      EventMachine.stop { exit }
    }
  end
end
```

The same example can be rewritten to use
`AMQP::Channel#queue`:

``` ruby
channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
  puts "#{queue.name} is ready to go."
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

# Declaring a temporary exclusive queue
AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  AMQP::Channel.new do |channel, open_ok|
    channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
      puts "#{queue.name} is ready to go."

      connection.close {
        EventMachine.stop { exit }
      }
    end
  end
end
```

Exclusive queues may only be accessed by the current connection and are
deleted when that connection closes. The declaration of an exclusive
queue by other connections is not allowed and will result in a
channel-level exception with the code `405 (RESOURCE_LOCKED)` and a reply
message similar to

``` ruby
require "rubygems"
require 'amqp'


puts "=> Queue exclusivity violation results "
puts
EventMachine.run do
  connection1 = AMQP.connect("amqp://guest:guest@dev.rabbitmq.com")
  channel1    = AMQP::Channel.new(connection1)

  connection2 = AMQP.connect("amqp://guest:guest@dev.rabbitmq.com")
  channel2    = AMQP::Channel.new(connection2)

  channel1.on_error do |ch, close|
    puts "Handling a channel-level exception on channel1: #{close.reply_text}, #{close.inspect}"
  end
  channel2.on_error do |ch, close|
    puts "Handling a channel-level exception on channel2: #{close.reply_text}, #{close.inspect}"
  end

  name = "amqpgem.examples.queue"
  channel1.queue(name, :auto_delete => true, :exclusive => true)
  # declare a queue with the same name on a different connection
  channel2.queue(name, :auto_delete => true, :exclusive => true)


  EventMachine.add_timer(3.5) do
    connection1.close {
      connection2.close {
        EventMachine.stop { exit }
      }
    }
  end
end
```

## Binding queues to exchanges

In order to receive messages, a queue needs to be bound to at least one
exchange. Most of the time binding is explcit (done by applications). To
bind a queue to an exchange, use `AMQP::Queue#bind` where
the argument passed can be either an `AMQP::Exchange`
instance or a string.

``` ruby
queue.bind(exchange) do |bind_ok|
  puts "Just bound #{queue.name} to #{exchange.name}"
end
```

Full example:

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

The same example using a string without callback:

``` ruby
queue.bind("amq.fanout")
```

Full example:

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

## Subscribing to receive messages (“push API”)

To set up a queue subscription to enable an application to receive
messages as they arrive in a queue, one uses the
`AMQP::Queue#subscribe` method. Then when a message
arrives, the message header (metadata) and body (payload) are passed to
the handler:

``` ruby
queue.subscribe do |metadata, payload|
  puts "Received a message: #{payload.inspect}."
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue|
    queue.bind(exchange).subscribe do |metadata, payload|
      puts "Received a message: #{payload.inspect}. Shutting down..."

      connection.close { EventMachine.stop }
    end

    EventMachine.add_timer(0.2) do
      puts "=> Publishing..."
      exchange.publish("Ohai!")
    end
  end
end
```

Subscriptions for message delivery are usually referred to as
<span class="note">consumers</span> in the AMQP 0.9.1 specification,
client library documentation and books. Consumers last as long as the
channel that they were declared on, or until client cancels them
(unsubscribes).

Consumers are identified by <span class="note">consumer tags</span>. If
you need to obtain the consumer tag of a subscribed queue then use
`AMQP::Queue#consumer_tag`.

### Accessing message metadata

The <span class="note">header</span> object in the example above
provides access to message metadata and delivery information:

 * Message content type
 * Message content encoding
 * Message routing key
 * Message delivery mode (persistent or not)
 * Consumer tag this delivery is for
 * Delivery tag
 * Message priority
 * Whether or not message is redelivered
 * Producer application id

and so on. An example to demonstrate how to access some of those
attributes:

``` ruby
# producer
exchange.publish("Hello, world!",
                 :app_id      => "amqpgem.example",
                 :priority    => 8,
                 :type        => "kinda.checkin",
                 # headers table keys can be anything
                 :headers     => {
                   :coordinates => {
                     :latitude  => 59.35,
                     :longitude => 18.066667
                   },
                   :participants => 11,
                   :venue        => "Stockholm"
                 },
                 :timestamp   => Time.now.to_i)

# consumer
queue.subscribe do |metadata, payload|
  puts "metadata.routing_key : #{metadata.routing_key}"
  puts "metadata.content_type: #{metadata.content_type}"
  puts "metadata.priority    : #{metadata.priority}"
  puts "metadata.headers     : #{metadata.headers.inspect}"
  puts "metadata.timestamp   : #{metadata.timestamp.inspect}"
  puts "metadata.type        : #{metadata.type}"
  puts "metadata.delivery_tag: #{metadata.delivery_tag}"
  puts "metadata.redelivered : #{metadata.redelivered?}"

  puts "metadata.app_id      : #{metadata.app_id}"
  puts "metadata.exchange    : #{metadata.exchange}"
  puts
  puts "Received a message: #{payload}."
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."

  channel  = AMQP::Channel.new(connection)
  queue    = channel.queue("amqpgem.examples.hello_world", :auto_delete => true)
  exchange = channel.direct("amq.direct")

  queue.bind(exchange)

  channel.on_error do |ch, channel_close|
    puts channel_close.reply_text
    connection.close { EventMachine.stop }
  end

  queue.subscribe do |metadata, payload|
    puts "metadata.routing_key : #{metadata.routing_key}"
    puts "metadata.content_type: #{metadata.content_type}"
    puts "metadata.priority    : #{metadata.priority}"
    puts "metadata.headers     : #{metadata.headers.inspect}"
    puts "metadata.timestamp   : #{metadata.timestamp.inspect}"
    puts "metadata.type        : #{metadata.type}"
    puts "metadata.delivery_tag: #{metadata.delivery_tag}"
    puts "metadata.redelivered : #{metadata.redelivered}"

    puts "metadata.app_id      : #{metadata.app_id}"
    puts "metadata.exchange    : #{metadata.exchange}"
    puts
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close {
      EventMachine.stop { exit }
    }
  end

  exchange.publish("Hello, world!",
                   :app_id      => "amqpgem.example",
                   :priority    => 8,
                   :type        => "kinda.checkin",
                   # headers table keys can be anything
                   :headers     => {
                     :coordinates => {
                       :latitude  => 59.35,
                       :longitude => 18.066667
                     },
                     :participants => 11,
                     :venue        => "Stockholm"
                   },
                   :timestamp   => Time.now.to_i)
end
```

### Exclusive consumers

Consumers can request exclusive access to the queue (meaning only this
consumer can access the queue). This is useful when you want a
long-lived shared queue to be temporarily accessible by just one
application (or thread, or process). If the application employing the
exclusive consumer crashes or loses the TCP connection to the broker,
then the channel is closed and the exclusive consumer is cancelled.

To exclusively receive messages from the queue, pass the “:exclusive”
option to `AMQP::Queue#subscribe`:

``` ruby
queue.subscribe(:exclusive => true) do |metadata, payload|
  # message handling logic...
end
```

TBD: describe what happens when exclusivity property is violated and how
to handle it.

### Using multiple consumers per queue

Historically, amqp gem versions before 0.8.0.RC14 (current master branch
in the repository) have had a “one consumer per Queue instance”
limitation. Previously, to work around this problem, application
developers had to open multiple channels and work with multiple queue
instances on different channels. This is not very convenient and is
surprising for developers familiar with AMQP clients for other
languages.

With more and more Ruby implementations dropping the
[GIL](http://en.wikipedia.org/wiki/Global_Interpreter_Lock), load
balancing between multiple consumers in the same queue in the same OS
process has become more and more common. In certain cases, even
applications that do not need any concurrency benefit from having
multiple consumers on the same queue in the same process.

Starting from amqp gem 0.8.0, it is possible to add any number of
consumers by instantiating `AMQP::Consumer` directly:

``` ruby
# non-exclusive consumer, consumer tag is generated
consumer1 = AMQP::Consumer.new(channel, queue)

# non-exclusive consumer, consumer tag is explicitly given
consumer2 = AMQP::Consumer.new(channel, queue, "#{queue.name}-consumer-#{rand}-#{Time.now}")

# exclusive consumer, consumer tag is generated
consumer3 = AMQP::Consumer.new(channel, queue, nil, true)
```

Instantiated consumers do not begin consuming messages immediately. This
is because in certain cases, it is useful to add a consumer but make it
active at a later time. To consume messages, use the
`AMQP::Consumer#consume` method in combination with
`AMQP::Consumer#on_delivery`:

``` ruby
consumer1.consume.on_delivery do |metadata, payload|
  @consumer1_mailbox << payload
end
```

`AMQP::Consumer#on_delivery` takes a block that is used
exactly like the block passed to `AMQP::Queue#subscribe`.
In fact, `AMQP::Queue#subscribe` uses
`AMQP::Consumer` under the hood, adding a
<span class="note">default consumer</span> to the queue.

<p class="alert alert-error">
Default consumers do not have any special properties, they just provide
a convenient way for application developers to register multiple
consumers and a means of preserving backwards compatibility. Application
developers are always free to use `AMQP::Consumer` instances directly, or
intermix them with `AMQP::Queue#subscribe`.
</p>

Most of the public API methods on `AMQP::Consumer` return
self, so it is possible to use method chaining extensively. An example
from [amqp gem spec
suite](https://github.com/ruby-amqp/amqp/tree/master/spec):

``` ruby
consumer1 = AMQP::Consumer.new(@channel, @queue).consume.on_delivery { |metadata, payload| mailbox1 << payload }
consumer2 = AMQP::Consumer.new(@channel, @queue).consume.on_delivery { |metadata, payload| mailbox2 << payload }
```

To cancel a particular consumer, use
`AMQP::Consumer#cancel` method. To cancel a default queue
consumer, use `AMQP::Queue#unsubscribe`.

### Message acknowledgements

Consumer applications - applications that receive and process messages -
may occasionally fail to process individual messages, or will just
crash. There is also the possibility of network issues causing problems.
This raises a question - “When should the AMQP broker remove messages
from queues?” The AMQP 0.9.1 specification proposes two choices:

 * After broker sends a message to an application (using either
basic.deliver or basic.get-ok methods).
 * After the application sends back an acknowledgement (using basic.ack
AMQP method).

The former choice is called the **automatic acknowledgement model**,
while the latter is called the **explicit acknowledgement model**. With
the explicit model, the application chooses when it is time to send an
acknowledgement. It can be right after receiving a message, or after
persisting it to a data store before processing, or after fully
processing the message (for example, successfully fetching a Web page,
processing and storing it into some persistent data store).

![](https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/006_amqp_091_message_acknowledgements.png)

If a consumer dies without sending an acknowledgement, the AMQP broker
will redeliver it to another consumer, or, if none are available at the
time, the broker will wait until at least one consumer is registered for
the same queue before attempting redelivery.

The acknowledgement model is chosen when a new consumer is registered
for a queue. By default, `AMQP::Queue#subscribe` will use
the **automatic** model. To switch to the **explicit** model, the “:ack”
(for "manual ack") option should be used:

``` ruby
queue.subscribe(:ack => true) do |metadata, payload|
  # message handling logic...
end
```

To demonstrate how redelivery works, let us have a look at the following
code example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'amqp'

puts "=> Subscribing for messages using explicit acknowledgements model"
puts

# this example uses Kernel#sleep and thus we must run EventMachine reactor in
# a separate thread, or nothing will be sent/received while we sleep() on the current thread.
t = Thread.new { EventMachine.run }
sleep(0.5)

# open two connections to imitate two apps
connection1 = AMQP.connect
connection2 = AMQP.connect
connection3 = AMQP.connect

channel_exception_handler = Proc.new { |ch, channel_close| EventMachine.stop; raise "channel error: #{channel_close.reply_text}" }

# open two channels

# first app will be given up to 3 messages at a time. If it doesn't
# ack any messages after it was delivered 3, messages will be routed to
# the app #2.
channel1    = AMQP::Channel.new(connection1, :prefetch => 3)
channel1.on_error(&channel_exception_handler)

# app #2 processes messages one-by-one and has to send and ack every time
channel2    = AMQP::Channel.new(connection2, :prefetch => 1)
channel2.on_error(&channel_exception_handler)

# app 3 will just publish messages
channel3    = AMQP::Channel.new(connection3)
channel3.on_error(&channel_exception_handler)

exchange = channel3.direct("amq.direct")

queue1    = channel1.queue("amqpgem.examples.acknowledgements.explicit", :auto_delete => false)
# purge the queue so that we don't get any redeliveries from previous runs
queue1.purge
queue1.bind(exchange).subscribe(:ack => true) do |metadata, payload|
  # do some work
  sleep(0.2)

  # acknowledge some messages, they will be removed from the queue
  if rand > 0.5
    # FYI: there is a shortcut, metadata.ack
    channel1.acknowledge(metadata.delivery_tag, false)
    puts "[consumer1] Got message ##{metadata.headers['i']}, ack-ed"
  else
    # some messages are not ack-ed and will remain in the queue for redelivery
    # when app #1 connection is closed (either properly or due to a crash)
    puts "[consumer1] Got message ##{metadata.headers['i']}, SKIPPPED"
  end
end

queue2    = channel2.queue!("amqpgem.examples.acknowledgements.explicit", :auto_delete => false)
queue2.subscribe(:ack => true) do |metadata, payload|
  metadata.ack
  # app 2 always acks messages
  puts "[consumer2] Received #{payload}, redelivered = #{metadata.redelivered}, ack-ed"
end

# after 2.5 seconds one of the consumers dies
EventMachine.add_timer(4.0) {
  connection1.close
  puts "----- Connection 1 is now closed (we pretend that it has crashed) -----"
}

EventMachine.add_timer(10.0) do
  # purge the queue so that we don't get any redeliveries on the next run
  queue2.purge {
    connection2.close {
      connection3.close { EventMachine.stop }
    }
  }
end


i = 0
EventMachine.add_periodic_timer(0.8) {
  3.times do
    exchange.publish("Message ##{i}", :headers => { :i => i })
    i += 1
  end
}


t.join
```

So what is going on here? This example uses three AMQP connections to
imitate three applications, one producer and two consumers. Each AMQP
connection opens a single channel:

``` ruby
# open multiple connections to imitate three apps
connection1 = AMQP.connect
connection2 = AMQP.connect
connection3 = AMQP.connect

channel_exception_handler = Proc.new { |ch, channel_close| EventMachine.stop; raise "channel error: #{channel_close.reply_text}" }

# open several channels
channel1    = AMQP::Channel.new(connection1)
channel1.on_error(&channel_exception_handler)
# ...

channel2    = AMQP::Channel.new(connection2)
channel2.on_error(&channel_exception_handler)
# ...

# app 3 will just publish messages
channel3    = AMQP::Channel.new(connection3)
channel3.on_error(&channel_exception_handler)
```

The consumers share a queue and the producer publishes messages to the
queue periodically using an <span class="note">`amq.direct`</span>
exchange. Both “applications” subscribe to receive messages using the
explicit acknowledgement model. The AMQP broker by default will send
each message to the next consumer in sequence (this kind of load
balancing is known as **round-robin**). This means that some messages
will be delivered to consumer #1 and some to consumer #2.

``` ruby
exchange = channel3.direct("amq.direct")

# ...

queue1    = channel1.queue("amqpgem.examples.acknowledgements.explicit", :auto_delete => false)
# purge the queue so that we do not get any redeliveries from previous runs
queue1.purge
queue1.bind(exchange).subscribe(:ack => true) do |metadata, payload|
  # do some work
  sleep(0.2)

  # acknowledge some messages, they will be removed from the queue
  if rand > 0.5
    # FYI: there is a shortcut, metadata.ack
    channel1.acknowledge(metadata.delivery_tag, false)
    puts "[consumer1] Got message ##{metadata.headers['i']}, ack-ed"
  else
    # odd messages are not ack-ed and will remain in the queue for redelivery
    # when app #1 connection is closed (either properly or due to a crash)
    puts "[consumer1] Got message ##{metadata.headers['i']}, SKIPPED"
  end
end

queue2    = channel2.queue!("amqpgem.examples.acknowledgements.explicit", :auto_delete => false)
queue2.subscribe(:ack => true) do |metadata, payload|
  metadata.ack
  # app 2 always acks messages
  puts "[consumer2] Received #{payload}, redelivered = #{metadata.redelivered}, ack-ed"
end
```

To demonstrate message redelivery we make consumer #1 randomly select
which messages to acknowledge. After 4 seconds we disconnect it (to
imitate a crash). When that happens, the AMQP broker redelivers
unacknowledged messages to consumer #2 which acknowledges them
unconditionally. After 10 seconds, this example closes all outstanding
connections and exits.

An extract of output produced by this example:

```
=> Subscribing for messages using explicit acknowledgements
model
[consumer2] Received Message #0, redelivered = false, ack-ed
[consumer1] Got message #1, SKIPPED
[consumer1] Got message #2, SKIPPED
[consumer1] Got message #3, ack-ed
[consumer2] Received Message #4, redelivered = false, ack-ed
[consumer1] Got message #5, SKIPPED
[consumer2] Received Message #6, redelivered = false, ack-ed
[consumer2] Received Message #7, redelivered = false, ack-ed
[consumer2] Received Message #8, redelivered = false, ack-ed
[consumer2] Received Message #9, redelivered = false, ack-ed
[consumer2] Received Message #10, redelivered = false, ack-ed
[consumer2] Received Message #11, redelivered = false, ack-ed
—— Connection 1 is now closed (we pretend that it has crashed) ——
[consumer2] Received Message #5, redelivered = true, ack-ed
[consumer2] Received Message #1, redelivered = true, ack-ed
[consumer2] Received Message #2, redelivered = true, ack-ed
[consumer2] Received Message #12, redelivered = false, ack-ed
[consumer2] Received Message #13, redelivered = false, ack-ed
[consumer2] Received Message #14, redelivered = false, ack-ed
[consumer2] Received Message #15, redelivered = false, ack-ed
[consumer2] Received Message #16, redelivered = false, ack-ed
[consumer2] Received Message #17, redelivered = false, ack-ed
[consumer2] Received Message #18, redelivered = false, ack-ed
[consumer2] Received Message #19, redelivered = false, ack-ed
[consumer2] Received Message #20, redelivered = false, ack-ed
[consumer2] Received Message #21, redelivered = false, ack-ed
[consumer2] Received Message #22, redelivered = false, ack-ed
[consumer2] Received Message #23, redelivered = false, ack-ed
[consumer2] Received Message #24, redelivered = false, ack-ed
[consumer2] Received Message #25, redelivered = false, ack-ed
[consumer2] Received Message #26, redelivered = false, ack-ed
[consumer2] Received Message #27, redelivered = false, ack-ed
[consumer2] Received Message #28, redelivered = false, ack-ed
[consumer2] Received Message #29, redelivered = false, ack-ed
[consumer2] Received Message #30, redelivered = false, ack-ed
[consumer2] Received Message #31, redelivered = false, ack-ed
[consumer2] Received Message #32, redelivered = false, ack-ed
[consumer2] Received Message #33, redelivered = false, ack-ed
[consumer2] Received Message #34, redelivered = false, ack-ed
[consumer2] Received Message #35, redelivered = false, ack-ed
```

As we can see, consumer #1 did not acknowledge three messages (labelled
1, 2 and 5):

```
[consumer1] Got message #1, SKIPPED
[consumer1] Got message #2, SKIPPED
…
[consumer1] Got message #5, SKIPPED
```

and then, once consumer #1 had “crashed”, those messages were
immediately redelivered to the consumer #2:

```
—— Connection 1 is now closed (we pretend that it has crashed) ——
[consumer2] Received Message #5, redelivered = true, ack-ed
[consumer2] Received Message #1, redelivered = true, ack-ed
[consumer2] Received Message #2, redelivered = true, ack-ed
```

To acknowledge a message use `AMQP::Channel#acknowledge`:

``` ruby
channel1.acknowledge(metadata.delivery_tag, false)
```

`AMQP::Channel#acknowledge` takes two arguments: message
**delivery tag** and a flag that indicates whether or not we want to
acknowledge multiple messages at once. Delivery tag is simply a
channel-specific increasing number that the server uses to identify
deliveries.

When acknowledging multiple messages at once, the delivery tag is
treated as “up to and including”. For example, if delivery tag = 5 that
would mean “acknowledge messages 1, 2, 3, 4 and 5”.

As a shortcut, it is possible to acknowledge messages using the
`AMQP::Header#ack` method:

``` ruby
queue2.subscribe(:ack => true) do |metadata, payload|
  metadata.ack
end
```

<p class="alert alert-error">
Acknowledgements are channel-specific. Applications must not receive
messages on one channel and acknowledge them on another.

</p>
<p class="alert alert-error">
A message MUST not be acknowledged more than once. Doing so will result
in a channel-level exception (PRECONDITION_FAILED) with an error
message like this: “PRECONDITION_FAILED - unknown delivery tag”
</p>

### Rejecting messages

When a consumer application receives a message, processing of that
message may or may not succeed. An application can indicate to the
broker that message processing has failed (or cannot be accomplished at
the time) by rejecting a message. When rejecting a message, an
application can ask the broker to discard or requeue it.

To reject a message use the `AMQP::Channel#reject` method:

``` ruby
queue.bind(exchange).subscribe do |metadata, payload|
  # reject but do not requeue (simply discard)
  channel.reject(metadata.delivery_tag)
end
```

in the example above, messages are rejected without requeueing (broker
will simply discard them). To requeue a rejected message, use the second
argument that `AMQP::Channel#reject` takes:

``` ruby
queue.bind(exchange).subscribe do |metadata, payload|
  # reject and requeue
  channel.reject(metadata.delivery_tag, true)
end
```

<p class="alert alert-error">
When there is only one consumer on a queue, make sure you do not create
infinite message delivery loops by rejecting and requeueing a message
from the same consumer over and over again.
</p>

Another way to reject a message is by using `AMQP::Header#reject`:

``` ruby
queue.bind(exchange).subscribe do |metadata, payload|
  # reject but do not requeue (simply discard)
  metadata.reject
end

queue.bind(exchange).subscribe do |metadata, payload|
  # reject and requeue
  metadata.reject(:requeue => true)
end
```

### Negative acknowledgements

Messages are rejected with the
`basic.reject` AMQP method. There is one
limitation that `basic.reject` has: there is
no way to reject multiple messages, as you can do with acknowledgements.
However, if you are using [RabbitMQ](http://rabbitmq.com), then there is
a solution. RabbitMQ provides an AMQP 0.9.1 extension known as [negative
acknowledgements](http://www.rabbitmq.com/extensions.html#negative-acknowledgements)
(nacks) and the amqp gem supports this extension. For more information,
please refer to the [Vendor-specific Extensions
guide](/articles/broker_specific_extensions/).

### QoS - Prefetching messages

For cases when multiple consumers share a queue, it is useful to be able
to specify how many messages each consumer can be sent at once before
sending the next acknowledgement. This can be used as a simple load
balancing technique to improve throughput if messages tend to be
published in batches. For example, if a producing application sends
messages every minute because of the nature of the work it is doing.

Imagine a website that takes data from social media sources like Twitter
or Facebook during the Champions League final (or the Superbowl), and
then calculates how many tweets mention a particular team during the
last minute. The site could be structured as 3 applications:

 * A crawler that uses streaming APIs to fetch tweets/statuses,
normalizes them and sends them in JSON for processing by other
applications (“app A”).
  * A calculator that detects what team is mentioned in a message,
updates statistics and pushes an update to the Web UI once a minute
(“app B”).
  * A Web UI that fans visit to see the stats (“app C”).

In this imaginary example, the “tweets per second” rate will vary, but
to improve the throughput of the system and to decrease the maximum
number of messages that the AMQP broker has to hold in memory at once,
applications can be designed in such a way that application “app B”, the
“calculator”, receives 5000 messages and then acknowledges them all at
once. The broker will not send message 5001 unless it receives an
acknowledgement.

In AMQP 0.9.1 parlance this is know as **QoS** or **message prefetching**.
Prefetching is configured on a per-channel (typically) or per-connection
(rarely used) basis. To configure prefetching per channel, pass the
`:prefetch` option to the Channel constructor. Let us return to the example
we used in the “Message acknowledgements” section:

``` ruby
# app #1 will be given up to 3 messages at a time. If it does not
# send an ack after receiving the messages, then the messages will
# be routed to app #2.
channel1    = AMQP::Channel.new(connection1, :prefetch => 3)

# app #2 processes messages one-by-one and has to send an ack after receiving each message
channel2    = AMQP::Channel.new(connection2, :prefetch => 1)
```

In that example, one consumer prefetches three messages and another
consumer prefetches just one. If we take a look at the output that the
example produces, we will see that `consumer1` fetched four messages
and acknowledged one. After that, all subsequent messages were delivered
to `consumer2`:

```
[consumer2] Received Message #0, redelivered = false, ack-ed
[consumer1] Got message #1, SKIPPED
[consumer1] Got message #2, SKIPPED
[consumer1] Got message #3, ack-ed
[consumer2] Received Message #4, redelivered = false, ack-ed
[consumer1] Got message #5, SKIPPED
—
 by now consumer 1 has received three messages it did not acknowledge.
 With :prefetch => 3, AMQP broker will not send it any more messages until
consumer 1 sends an ack
—
[consumer2] Received Message #6, redelivered = false, ack-ed
[consumer2] Received Message #7, redelivered = false, ack-ed
[consumer2] Received Message #8, redelivered = false, ack-ed
[consumer2] Received Message #9, redelivered = false, ack-ed
[consumer2] Received Message #10, redelivered = false, ack-ed
[consumer2] Received Message #11, redelivered = false, ack-ed
```

<span class="alert alert-error">The prefetching setting is ignored for
consumers that do not use explicit acknowledgements.</span>

## How message acknowledgements relate to transactions and Publisher Confirms

In cases where you cannot afford to lose a single message, AMQP 0.9.1
applications can use one or a combination of the following protocol
features:

 * Publisher confirms (a RabbitMQ-specific extension to AMQP 0.9.1)
 * Publishing messages as immediate
 * Transactions (noticeable overhead)

This topic is covered in depth in the [Working With
Exchanges](/articles/working_with_exchanges/) guide. In this guide, we
will only mention how message acknowledgements are related to AMQP
transactions and the Publisher Confirms extension.

Let us consider a publisher application (P) that communications with a
consumer (C) using AMQP 0.9.1. Their communication can be graphically
represented like this:

```
-----       -----       -----
|   |   S1  |   |   S2  |   |
| P | ====> | B | ====> | C |
|   |       |   |       |   |
-----       -----       -----
```

We have two network segments, S1 and S2. Each of them may fail. P is
concerned with making sure that messages cross S1, while broker (B) and
C are concerned with ensuring that messages cross S2 and are only
removed from the queue when they are processed successfully.

Message acknowledgements cover reliable delivery over S2 as well as
successful processing. For S1, P has to use transactions (a heavyweight
solution) or the more lightweight Publisher Confirms RabbitMQ extension.

## Fetching messages when needed (“pull API”)

The AMQP 0.9.1 specification also provides a way for applications to
fetch (pull) messages from the queue only when necessary. For that, use
`AMQP::Queue#pop`:

``` ruby
queue.pop do |metadata, payload|
  if payload
    puts "Fetched a message: #{payload.inspect}, content_type: #{metadata.content_type}. Shutting down..."
  else
    puts "No messages in the queue"
  end
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange)
    puts "Bound. Publishing a message..."
    exchange.publish("Ohai!")

    EventMachine.add_timer(0.5) do
      queue.pop do |metadata, payload|
        if payload
          puts "Fetched a message: #{payload.inspect}, content_type: #{metadata.content_type}. Shutting down..."
        else
          puts "No messages in the queue"
        end

        connection.close { EventMachine.stop }
      end
    end
  end
end
```

If the queue is empty, then the `payload` argument will be nil,
otherwise arguments are identical to those of the
`AMQP::Queue#subscribe` callback.

## Unsubscribing from messages

Sometimes it is necessary to unsubscribe from messages without deleting
a queue. To do that, use the `AMQP::Queue#unsubscribe`
method:

``` ruby
queue.unsubscribe
```

By default `AMQP::Queue#unsubscribe` uses the “:noack”
option to inform the broker that there is no need to send a
confirmation. In other words, it does not expect you to pass in a
callback, because the consumer tag on the instance and the registered
callback for messages are cleared immediately.

If an application needs to execute a piece of code after the broker
response arrives, `AMQP::Queue#unsubscribe` takes an optional callback:

``` ruby
queue.unsubscribe do |unbind_ok|
  # server response arrived, handle it if necessary...
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.bind(exchange).subscribe do |headers, payload|
      puts "Received a new message"
    end

    EventMachine.add_timer(0.3) do
      queue.unsubscribe
      puts "Unsubscribed. Shutting down..."

      connection.close { EventMachine.stop }
    end # EventMachine.add_timer
  end # channel.queue
end
```

In AMQP parlance, unsubscribing from messages is often referred to as
“cancelling a consumer”. Once a consumer is cancelled, messages will no
longer be delivered to it, however, due to the asynchronous nature of
the protocol, it is possible for “in flight” messages to be received
after this call completes.

Fetching messages with `AMQP::Queue#pop` is still possible
even after a consumer is cancelled.

## Unbinding queues from exchanges

To unbind a queue from an exchange use
`AMQP::Queue#unbind`:

``` ruby
queue.unbind(exchange)
```

Full example:

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

Note that trying to unbind a queue from an exchange that the queue was
never bound to will result in a channel-level exception.

## Querying the number of messages in a queue

It is possible to query the number of messages sitting in the queue by
declaring the queue with the `:passive` attribute set. The response
(`queue.declare-ok` AMQP method) will include the number of messages
along with other attributes. However, the amqp gem provides a
convenience method, `AMQP::Queue#status`:

``` ruby
queue.status do |number_of_messages, number_of_consumers|
  puts
  puts "# of messages in the queue #{queue.name} = #{number_of_messages}"
  puts
end
```

Full example:

``` ruby
require 'rubygems'
require 'amqp'

puts "=> Queue#status example"
puts
AMQP.start(:host => 'localhost') do |connection|
  channel   = AMQP::Channel.new(connection)

  queue_name = "amqpgem.integration.queue.status.queue"
  exchange   = channel.fanout("amqpgem.integration.queue.status.fanout", :auto_delete => true)
  queue      = channel.queue(queue_name, :auto_delete => true).bind(exchange)

  100.times do |i|
    print "."
    exchange.publish(Time.now.to_i.to_s + "_#{i}", :key => queue_name)
  end
  $stdout.flush

  EventMachine.add_timer(0.5) do
    queue.status do |number_of_messages, number_of_consumers|
      puts
      puts "# of messages in the queue #{queue.name} = #{number_of_messages}"
      puts
      queue.purge
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close { EventMachine.stop }
  end

  Signal.trap "INT", show_stopper
  EventMachine.add_timer(2, show_stopper)
end
```

## Querying the number of consumers on a queue

It is possible to query the number of consumers on a queue by declaring
the queue with the `:passive` attribute set. The response
(`queue.declare-ok` AMQP method) will include the number of consumers
along with other attributes. However, the amqp gem provides a
convenience method, `AMQP::Queue#status`:

``` ruby
queue.status do |number_of_messages, number_of_consumers|
  puts
  puts "# of consumers on the queue #{queue.name} = #{number_of_consumers}"
  puts
end
```

Full example:

``` ruby
require 'rubygems'
require 'amqp'

puts "=> Queue#status example"
puts
AMQP.start(:host => 'localhost') do |connection|
  channel   = AMQP::Channel.new(connection)

  queue_name = "amqpgem.integration.queue.status.queue"
  exchange   = channel.fanout("amqpgem.integration.queue.status.fanout", :auto_delete => true)
  queue      = channel.queue(queue_name, :auto_delete => true).bind(exchange)

  100.times do |i|
    print "."
    exchange.publish(Time.now.to_i.to_s + "_#{i}", :key => queue_name)
  end
  $stdout.flush

  EventMachine.add_timer(0.5) do
    queue.status do |number_of_messages, number_of_consumers|
      puts
      puts "# of consumer on the queue #{queue.name} = #{number_of_consumers}"
      puts
      queue.purge
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close { EventMachine.stop }
  end

  Signal.trap "INT", show_stopper
  EventMachine.add_timer(2, show_stopper)
end
```

## Purging queues

It is possible to purge a queue (remove all of the messages from it)
using `AMQP::Queue#purge`:

``` ruby
queue.purge
```

This method takes an optional callback. However, remember that this
operation is performed asynchronously. To run a piece of code when the
AMQP broker confirms that a queue has been purged, use a callback that
`AMQP::Queue#purge` takes:

``` ruby
queue.purge do |_|
  puts "Purged #{queue.name}"
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
  channel = AMQP::Channel.new(connection)
  channel.on_error do |ch, channel_close|
    raise "Channel-level exception: #{channel_close.reply_text}"
  end
  exchange = channel.fanout("amq.fanout")

  channel.queue("", :auto_delete => true, :exclusive => true) do |queue, declare_ok|
    queue.purge do |_|
      puts "Purged #{queue.name}"
    end

    EventMachine.add_timer(0.5) do
      connection.close { EventMachine.stop }
    end # EventMachine.add_timer
  end # channel.queue
end
```

Note that this example purges a newly declared queue with a unique
server-generated name. When a queue is declared, it is empty, so for
server-named queues, there is no need to purge them before they are
used.

## Deleting queues

To delete a queue, use `AMQP::Queue#delete`. When a queue
is deleted, all of the messages in it are deleted as well.

``` ruby
queue.delete
```

This method takes an optional callback. However, remember that this
operation is performed asynchronously. To run a piece of code when the
AMQP broker confirms that a queue has been deleted, use a callback that
`AMQP::Queue#delete` takes:

``` ruby
queue.delete do |_|
  puts "Deleted #{queue.name}"
end
```

Full example:

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
    EventMachine.add_timer(0.5) do
      queue.delete do
        puts "Deleted #{queue.name}"
        connection.close { EventMachine. stop }
      end
    end # EventMachine.add_timer
  end # channel.queue
end
```

## Objects as message consumers and unit testing consumers in isolation

Since Ruby is a genuine object-oriented language, it is important to
demonstrate how the Ruby amqp gem can be integrated into rich
object-oriented code. This part of the guide focuses on queues and the
problems/solutions concerning consumer applications (applications that
primarily receive and process messages, as opposed to producers that
publish them).

An `AMQP::Queue#subscribe` callback does not have to be a
block. It can be any Ruby object that responds to the `call` method. A
common technique is to combine
`Object#method` and `Method#to_proc`
and use object methods as message handlers.

An example to demonstrate this technique:

``` ruby
class Consumer

  #
  # API
  #

  def initialize(channel, queue_name = AMQ::Protocol::EMPTY_STRING)
    @queue_name = queue_name

    @channel    = channel
    # Consumer#handle_channel_exception will handle channel
    # exceptions. Keep in mind that you can only register one error handler,
    # so the last one registered "wins".
    @channel.on_error(&method(:handle_channel_exception))
  end # initialize

  def start
    @queue = @channel.queue(@queue_name, :exclusive => true)
    # #handle_message method will be handling messages routed to @queue
    @queue.subscribe(&method(:handle_message))
  end # start



  #
  # Implementation
  #

  def handle_message(metadata, payload)
    puts "Received a message: #{payload}, content_type = #{metadata.content_type}"
  end # handle_message(metadata, payload)

  def handle_channel_exception(channel, channel_close)
    puts "Oops... a channel-level exception: code = #{channel_close.reply_code}, message = #{channel_close.reply_text}"
  end # handle_channel_exception(channel, channel_close)
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

class Consumer

  #
  # API
  #

  def initialize(channel, queue_name = AMQ::Protocol::EMPTY_STRING)
    @queue_name = queue_name

    @channel    = channel
    @channel.on_error(&method(:handle_channel_exception))
  end # initialize

  def start
    @queue = @channel.queue(@queue_name, :exclusive => true)
    @queue.subscribe(&method(:handle_message))
  end # start



  #
  # Implementation
  #

  def handle_message(metadata, payload)
    puts "Received a message: #{payload}, content_type = #{metadata.content_type}"
  end # handle_message(metadata, payload)

  def handle_channel_exception(channel, channel_close)
    puts "Oops... a channel-level exception: code = #{channel_close.reply_code}, message = #{channel_close.reply_text}"
  end # handle_channel_exception(channel, channel_close)
end


class Producer

  #
  # API
  #

  def initialize(channel, exchange)
    @channel  = channel
    @exchange = exchange
  end # initialize(channel, exchange)

  def publish(message, options = {})
    @exchange.publish(message, options)
  end # publish(message, options = {})
end


AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel  = AMQP::Channel.new(connection)
  worker   = Consumer.new(channel, "amqpgem.objects.integration")
  worker.start

  producer = Producer.new(channel, channel.default_exchange)
  puts "Publishing..."
  producer.publish("Hello, world", :routing_key => "amqpgem.objects.integration")

  # stop in 2 seconds
  EventMachine.add_timer(2.0) { connection.close { EventMachine.stop } }
end
```

In this example, `Consumer` instances have to be
instantiated with an `AMQP::Channel` instance. If the
message handling was done by an aggregated object, it would completely
separate the handling logic and would be make it easy to unit test in
isolation:

``` ruby
class Consumer

  #
  # API
  #

  def handle_message(metadata, payload)
    puts "Received a message: #{payload}, content_type = #{metadata.content_type}"
  end # handle_message(metadata, payload)
end


class Worker

  #
  # API
  #


  def initialize(channel, queue_name = AMQ::Protocol::EMPTY_STRING, consumer = Consumer.new)
    @queue_name = queue_name

    @channel    = channel
    @channel.on_error(&method(:handle_channel_exception))

    @consumer   = consumer
  end # initialize

  def start
    @queue = @channel.queue(@queue_name, :exclusive => true)
    @queue.subscribe(&@consumer.method(:handle_message))
  end # start


  #
  # Implementation
  #

  def handle_channel_exception(channel, channel_close)
    puts "Oops... a channel-level exception: code = #{channel_close.reply_code}, message = #{channel_close.reply_text}"
  end # handle_channel_exception(channel, channel_close)
end
```

Full example:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

class Consumer

  #
  # API
  #

  def handle_message(metadata, payload)
    puts "Received a message: #{payload}, content_type = #{metadata.content_type}"
  end # handle_message(metadata, payload)
end


class Worker

  #
  # API
  #


  def initialize(channel, queue_name = AMQ::Protocol::EMPTY_STRING, consumer = Consumer.new)
    @queue_name = queue_name

    @channel    = channel
    @channel.on_error(&method(:handle_channel_exception))

    @consumer   = consumer
  end # initialize

  def start
    @queue = @channel.queue(@queue_name, :exclusive => true)
    @queue.subscribe(&@consumer.method(:handle_message))
  end # start



  #
  # Implementation
  #

  def handle_channel_exception(channel, channel_close)
    puts "Oops... a channel-level exception: code = #{channel_close.reply_code}, message = #{channel_close.reply_text}"
  end # handle_channel_exception(channel, channel_close)
end


class Producer

  #
  # API
  #

  def initialize(channel, exchange)
    @channel  = channel
    @exchange = exchange
  end # initialize(channel, exchange)

  def publish(message, options = {})
    @exchange.publish(message, options)
  end # publish(message, options = {})


  #
  # Implementation
  #

  def handle_channel_exception(channel, channel_close)
    puts "Oops... a channel-level exception: code = #{channel_close.reply_code}, message = #{channel_close.reply_text}"
  end # handle_channel_exception(channel, channel_close)
end


AMQP.start("amqp://guest:guest@dev.rabbitmq.com") do |connection, open_ok|
  channel  = AMQP::Channel.new(connection)
  worker   = Worker.new(channel, "amqpgem.objects.integration")
  worker.start

  producer = Producer.new(channel, channel.default_exchange)
  puts "Publishing..."
  producer.publish("Hello, world", :routing_key => "amqpgem.objects.integration")

  # stop in 2 seconds
  EventMachine.add_timer(2.0) { connection.close { EventMachine.stop } }
end
```

Note that the <span class="note">Consumer</span> class demonstrated
above can be easily tested in isolation without spinning up any AMQP
connections:

``` ruby
require "ostruct"
require "json"

# RSpec example
describe Consumer do
  describe "when a new message arrives" do
    subject { described_class.new }

    let(:metadata) do
      o = OpenStruct.new

      o.content_type = "application/json"
      o
    end
    let(:payload)  { JSON.encode({ :command => "reload_config" }) }

    it "does some useful work" do
      # check preconditions here if necessary

      subject.handle_message(metadata, payload)

      # add your code expectations here
    end
  end
end
```

## Queue durability vs message durability

See [Durability guide](/articles/durability/)

## Error handling and recovery

See [Error handling and recovery guide](/articles/error_handling/)

## Vendor-specific extensions related to queues

See [Vendor-specific Extensions
guide](/articles/broker_specific_extensions/)

## What to read next

The documentation is organized as several [documentation guides](/),
covering all kinds of topics. Guides related to this one are:

 * [Working With Exchanges](/articles/working_with_exchanges/)
 * [Bindings](/articles/bindings/)
 * [Error handling and recovery](/articles/error_handling/)

RabbitMQ implements a number of extensions to AMQP 0.9.1 functionality
that are covered in the [Vendor-specific Extensions
guide](/articles/broker_specific_extensions/). At least one extension,
per-queue messages time-to-live (TTL), is related to this guide and can
be used with the amqp gem 0.8.0 and later.
