---
title: "RabbitMQ Extensions to AMQP 0.9.1 in amqp gem"
layout: article
---

## RabbitMQ extensions

amqp gem supports many RabbitMQ extensions to AMQP 0.9.1:

  * [Publisher confirms](http://www.rabbitmq.com/confirms.html)
  * [Negative acknowledgements](http://www.rabbitmq.com/nack.html) (basic.nack)
  * [Exchange-to-Exchange Bindings](http://www.rabbitmq.com/e2e.html)
  * [Alternate Exchanges](http://www.rabbitmq.com/ae.html)
  * [Per-queue Message Time-to-Live](http://www.rabbitmq.com/ttl.html#per-queue-message-ttl)
  * [Per-message Time-to-Live](http://www.rabbitmq.com/ttl.html#per-message-ttl)
  * [Queue Leases](http://www.rabbitmq.com/ttl.html#queue-ttl)
  * [Consumer Cancellation Notifications](http://www.rabbitmq.com/consumer-cancel.html)
  * [Sender-selected Distribution](http://www.rabbitmq.com/sender-selected.html)
  * [Dead Letter Exchanges](http://www.rabbitmq.com/dlx.html)
  * [Validated user_id](http://www.rabbitmq.com/validated-user-id.html)

## Enabling RabbitMQ extensions

If you are using RabbitMQ and want to use these
extensions, simply replace

``` ruby
require "amqp"
```

with

``` ruby
require "amqp"
require "amqp/extensions/rabbitmq"
```

## Per-queue Message Time-to-Live

Per-queue Message Time-to-Live (TTL) is a RabbitMQ extension to AMQP
0.9.1 that allows developers to control how long a message published to
a queue can live before it is discarded. A message that has been in the
queue for longer than the configured TTL is said to be dead. Dead
messages will not be delivered to consumers and cannot be fetched using
the **basic.get** operation (`AMQP::Queue#pop`).

Message TTL is specified using the **x-message-ttl** argument on
declaration. With the amqp gem, you pass it to
`AMQP::Queue#initialize`
or`AMQP::Channel#queue`:

    <code># 1000 millisecondschannel.queue("", :arguments => { "x-message-ttl" => 1000 })</code>

When a published message is routed to multiple queues, each of the
queues gets a *copy of the message*. If the message subsequently dies in
one of the queues, it has no effect on copies of the message in other
queues.

### Example

The example below sets the message TTL for a new server-named queue to
be 1000 milliseconds. It then publishes several messages that are routed
to the queue and tries to fetch messages using the **basic.get** AMQP
method (`AMQP::Queue#pop` after 0.7 and 1.5 seconds:

``` ruby
require 'amqp'
require "amqp/extensions/rabbitmq"

AMQP.start do |connection|
  puts "Connected!"
  channel = AMQP::Channel.new(connection)
  channel.on_error do |ch, channel_close|
    puts "Oops! a channel-level exception: #{channel_close.reply_text}"
  end

  x = channel.fanout("amq.fanout")
  channel.queue("", :auto_delete => true, :arguments => { "x-message-ttl" => 1000 }) do |q|
    puts "Declared a new server-named queue: #{q.name}"
    q.bind(x)

    EventMachine.add_timer(0.3) do
      10.times do |i|
        puts "Publishing message ##{i}"
        x.publish("Message ##{i}")
      end
    end

    EventMachine.add_timer(0.7) do
      q.pop do |headers, payload|
        puts "Got a message: #{payload}"
      end
    end

    EventMachine.add_timer(1.5) do
      q.pop do |headers, payload|
        if payload.nil?
          puts "No messages in the queue"
        else
          raise "x-message-ttl didn't seem to work (timeout isn't up)"
        end
      end
    end
  end

  show_stopper = Proc.new {
    AMQP.stop { EventMachine.stop }
  }


  EM.add_timer(3, show_stopper)
  Signal.trap('INT',  show_stopper)
  Signal.trap('TERM', show_stopper)
end
```

### Learn More

See also rabbitmq.com section on [Per-queue Message
TTL](http://www.rabbitmq.com/ttl.html#per-queue-message-ttl)

## Publisher Confirms (Publisher Acknowledgements)

In some situations it is essential that no messages are lost. The only
reliable way of ensuring this is by using confirmations. The [Publisher
Confirms AMQP
extension](http://www.rabbitmq.com/blog/2011/02/10/introducing-publisher-confirms/)
was designed to solve the reliable publishing problem.

Publisher confirms are similar to message acknowledgements documented in
the [Working With Queues](/articles/working_with_queues/) guide but
involve a publisher and the AMQP broker instead of a consumer and the
AMQP broker.

![](https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/006_amqp_091_message_acknowledgements.png)

![](https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/007_rabbitmq_publisher_confirms.png)

### Public API

To use publisher confirmations, first put the channel into confirmation
mode using `AMQP::Channel#confirm_select`:

``` ruby
channel.confirm_select
```

From this moment on, every message published on this channel will cause
the channel’s *publisher index* (message counter) to be incremented. It
is possible to access the index using
`AMQP::Channel#publisher_index` method. To check whether
the channel is in confirmation mode, use the
`AMQP::Channel#uses_publisher_confirmations?`
predicate.
To handle AMQP broker acknowledgements, define a handler using
`AMQP::Channel#on_ack`, for example:

``` ruby
channel.on_ack do |basic_ack|
 puts "Received basic_ack: multiple = #{basic_ack.multiple}, delivery_tag = #{basic_ack.delivery_tag}"
end
```

The delivery tag will indicate the number of confirmed messages. If the
**multiple** attribute is true, the confirmation is for all messages up
to the number that the delivery tag indicates. In other words, an AMQP
broker may confirm just one message or a batch of them.

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../../lib", __FILE__))
require 'amqp'
require "amqp/extensions/rabbitmq"

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connecting to AMQP broker. Running #{AMQP::VERSION} version of the gem..."

  AMQP::Channel.new(connection) do |channel|
    puts "Channel #{channel.id} is now open"

    channel.confirm_select
    channel.on_error { |ch, channel_close| puts "Oops! a channel-level exception: #{channel_close.reply_text}" }
    channel.on_ack   { |basic_ack| puts "Received basic_ack: multiple = #{basic_ack.multiple}, delivery_tag = #{basic_ack.delivery_tag}" }

    x = channel.fanout("amq.fanout")
    channel.queue("", :auto_delete => true) do |q|
      q.bind(x).subscribe(:ack => true) do |header, payload|
        puts "Received #{payload}"
      end
    end

    EventMachine.add_timer(0.5) do
      10.times do |i|
        puts "Publishing message ##{i + 1}"
        x.publish("Message ##{i + 1}")
      end
    end
  end

  show_stopper = Proc.new {
    connection.close { EventMachine.stop }
  }

  EM.add_timer(6, show_stopper)
  Signal.trap('INT',  show_stopper)
  Signal.trap('TERM', show_stopper)
end
```

### Learn More

See also rabbitmq.com section on [Confirms aka Publisher
Acknowledgements](http://www.rabbitmq.com/confirms.html)

## basic.nack

The AMQP 0.9.1 specification defines the basic.reject method that allows
clients to reject individual, delivered messages, instructing the broker
to either discard them or requeue them. Unfortunately, basic.reject
provides no support for negatively acknowledging messages in bulk.

To solve this, RabbitMQ supports the basic.nack method that provides all
of the functionality of basic.reject whilst also allowing for bulk
processing of messages.

### Public API

When RabbitMQ extensions are loaded, the
`AMQP::Channel#reject` method is overriden via a mixin to
take one additional argument: multi (defaults to false). When the
‘multi’ argument is passed with a value of ‘true’, then the amqp gem
will use the basic.nack AMQP method, instead of basic.reject, to reject
multiple messages at once. Otherwise, basic.reject is used as usual.

### Learn More

See also rabbitmq.com section on [Confirms aka Publisher
Acknowledgements](http://www.rabbitmq.com/nack.html)

## Alternate Exchanges

Alternate Exchanges is a RabbitMQ extension to AMQP 0.9.1 that allows
developers to define “fallback” exchanges where unroutable messages will
be sent.

### Public API

To specify exchange A as an alternate exchange to exchange B, specify
the ‘alternate-exchange’ argument on declaration of B:

``` ruby
exchange1 = channel.fanout("ops.fallback",     :auto_delete => true)
exchange2 = channel.fanout("events.collector", :auto_delete => true, :arguments => { "alternate-exchange" => "ops.fallback" })
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../../lib", __FILE__))

require 'amqp'

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connecting to AMQP broker. Running #{AMQP::VERSION} version of the gem..."

  channel   = AMQP::Channel.new(connection)
  queue     = channel.queue("amqpgem.examples.hello_world", :auto_delete => true)
  exchange1 = channel.fanout("my.fanout1", :auto_delete => true)
  exchange2 = channel.fanout("my.fanout2", :auto_delete => true, :arguments => { "alternate-exchange" => "my.fanout1" })

  queue.bind(exchange1).subscribe do |payload|
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close { EventMachine.stop }
  end

  exchange1.publish "This message will be routed because of the binding",   :mandatory => true
  exchange2.publish "This message will be re-routed to alternate-exchange", :mandatory => true
end
```

### Learn More

See also rabbitmq.com section on [Alternate
Exchanges](http://www.rabbitmq.com/ae.html)

## Wrapping Up

With amqp gem you can use a number of RabbitMQ extensions to AMQP 0.9.1.
Some are special features in the library, while some other are used via
extra declaration attributes and message properties.
