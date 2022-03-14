---
title: "Durability and related matters"
layout: article
---

## About this guide

This guide covers queue, exchange and message durability, as well as
othertopics related to durability, for example, durability in cluster
environment.

This work is licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative
Commons Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
Github](https://github.com/ruby-amqp/rubyamqp.info).

## Covered versions

This guide covers Ruby amqp gem 1.7.0 and later versions.

## Entity durability and message persistence

### Durability of exchanges

AMQP separates the concept of entity durability (queues, exchanges) from
message persistence. Exchanges can be durable or transient. Durable
exchanges survive broker restart, transient exchanges do not (they have
to be redeclared when broker comes back online). Not all scenarios and
use cases mandate exchanges to be durable.

### Durability of queues

Durable queues are persisted to disk and thus survive broker restarts.
Queues that are not durable are called transient. Not all scenarios and
use cases mandate queues to be durable.

Note that **only durable queues can be bound to durable exchanges**.
This guarantees that it is possible to restore bindings on broker
restart.

Durability of a queue does not make *messages* that are routed to that
queue durable. If a broker is taken down and then brought back up,
durable queues will be re-declared during broker startup, however, only
*persistent* messages will be recovered.

### Message persistence

Messages may be published as persistent and this is what makes an AMQP
broker persist them to disk. If the server is restarted, the system
ensures that received persistent messages are not lost. Simply
publishing a message to a durable exchange or the fact that a queue to
which a message is routed is durable does not make that message
persistent. It all depends on the persistence mode of the message
itself. Publishing messages as persistent affects performance (just like
with data stores, durability comes at a certain cost to performance and
vice versa). Pass :persistent =\> true to
{ yard\_link AMQP::Exchange\#publish } to publish your message as
persistent.

### Transactions

TBD

### Publisher confirms

Because transactions carry certain (for some applications, significant)
overhead, RabbitMQ introduced an extension to AMQP 0.9.1 called
[publisher
confirms](http://www.rabbitmq.com/blog/2011/02/10/introducing-publisher-confirms/)
([documentation](http://www.rabbitmq.com/extensions.html#confirms)).

The amqp gem implements support for this extension, but it is not loaded
by default when you require “amqp”. To load it, use

``` ruby
require "amqp/extensions/rabbitmq"
```

and then define a callback for publisher confirms using
`AMQP::Channel#confirm`:

``` ruby
# enable publisher acknowledgements for this channel
channel.confirm_select

# define a callback that will be executed when message is acknowledged
channel.on_ack do |basic_ack|
  puts "Received an acknowledgement: delivery_tag = #{basic_ack.delivery_tag}, multiple = #{basic_ack.multiple}"
end

# define a callback that will be executed when message is rejected using basic.nack (a RabbitMQ-specific extension)
channel.on_nack do |basic_nack|
  puts "Received a nack: delivery_tag = #{basic_nack.delivery_tag}, multiple = #{basic_nack.multiple}"
end
```

Note that the same callback is used for all messages published via all
exchanges on the given channel.

### Clustering and High Availability

To achieve the degree of durability that critical applications need,
it is necessary but not enough to use durable queues, exchanges and
persistent messages. You need to use a cluster of brokers because
otherwise, a single hardware problem may bring a broker down
completely.

RabbitMQ offers a number of high availability features for both
scenarios with more
(LAN) and less (WAN) reliable network connections.

See the [RabbitMQ clustering](http://www.rabbitmq.com/clustering.html)
and [high availability](http://www.rabbitmq.com/ha.html) guides for
in-depth discussion of this topic.

### Highly Available (Mirrored) Queues

Whilst the use of clustering provides for greater durability of
critical systems, in order to achieve the highest level of resilience
for queues and messages, high availability configuration should be
used. This is because although exchanges and bindings survive the loss
of individual nodes by using clustering, messages do
not. Without mirroring, queue contents reside on exactly one node, thus
the loss of a node will cause message loss.

See the [RabbitMQ high availability\
guide](http://www.rabbitmq.com/ha.html) for more information about
mirrored queues.
