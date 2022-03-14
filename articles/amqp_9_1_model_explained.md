---
title: "AMQP 0.9.1 Model Explained"
layout: article
permalink: "amqp_9_1_model_explained/"
---

## About this guide

This guide explains the AMQP 0.9.1 Model used by RabbitMQ. Understanding
the AMQP Model will make a lot of other documentation, both for the Ruby
amqp gem and RabbitMQ itself, easier to follow. This work is licensed
under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative
Commons Attribution 3.0 Unported License</a> (including images &
stylesheets). The source is available [on
Github](https://github.com/ruby-amqp/rubyamqp.info).

### What this guide covers

 * High-level overview of the AMQP 0.9.1 Model
 * Key differences between the AMQP model and some other messaging
models
 * What exchanges are
 * What queues are
 * What bindings are
 * How AMQP protocol is structured and what AMQP methods are
 * AMQP 0.9.1 message attributes
 * What message acknowledgements are
 * What negative message acknowledgements are
 * and a lot of other things

## High-level overview of AMQP 0.9.1 and the AMQP Model

### What is AMQP

AMQP (Advanced Message Queuing Protocol) is a networking protocol that
enables conforming client applications to communicate with conforming
messaging middleware brokers.

### Why AMQP was created

Messaging solutions have been around since the 1970s with a view to
solving the problem of integrating incompatible products from diverse
vendors. Without the use of messaging middleware, the integration of
heterogenous systems has proved to be very expensive and complex.
However, messaging solutions, such as IBM Websphere MQ and Tibco
Enterprise Message Service, are also very costly and tend to be
exclusively employed by large companies (who can afford them),
especially those in the financial services industry.

There is also a problem with interoperability between messaging
solutions. Vendors have created their own proprietary messaging
protocols which do not interoperate with others, therefore resulting in
‘vendor lock-in’.

AMQP has multiple design goals but two of the most important are:

 * To produce an open standard for messaging middleware
 * To enable interoperability between various technologies and
platforms

There is a lot of software running on many operating systems built with
multiple programming languages running on various hardware architectures
and virtual machines. AMQP not only makes it possible for these
disparate systems to communicate with one another, but also enables
different products that implement AMQP to exchange information.

### Brokers and their role

Messaging brokers receive messages from *producers* (applications that
publish them) and route them to *consumers* (applications that process
them).

If you imagine the human body, then brokers would be equivalent to
centers of the nervous system and applications would be more like limbs.

### AMQP 0.9.1 Model in brief

The AMQP 0.9.1 Model has the following view of the world: messages are
published by producers to *exchanges*, often compared to post offices or
mailboxes. Exchanges then distribute message copies to *queues* using
rules called *bindings*. Then AMQP brokers either push messages to
*consumers* subscribed to queues, or consumers fetch/pull messages from
queues on demand.

![](https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/001_hello_world_example_routing.png)

When publishing a message, producers may specify various *message
attributes* (message metadata). Some of this metadata may be used by the
broker, however, the rest of it is completely opaque to the broker and
is only used by applications that receive the message.

Networks are unreliable and applications may fail to process messages,
therefore the AMQP Model has a notion of *message acknowledgements*:
when a message is pushed down to a consumer, the consumer *notifies the
broker*, either automatically, or as soon as the application developer
chooses to do so. When message acknowledgements are in use, a broker
will only completely remove a message from a queue when it receives a
notification for that message (or group of messages).

In certain situations, for example, when a message cannot be routed,
messages may be *returned* to producers, dropped, or, if the broker
implements an extension, placed into a so-called “dead letter queue”.
Producers choose how to handle situations like this by publishing
messages using certain parameters.

Queues, exchanges and bindings are commonly referred to as *AMQP
entities*.

### AMQP is a Programmable Protocol

AMQP 0.9.1 is a programmable protocol in the sense that AMQP entities
and routing schemes are defined by applications themselves, not a broker
administrator. Accordingly, provision is made for protocol operations
that declare queues and exchanges, define bindings between them,
subscribe to queues and so on.

This gives application developers a lot of freedom but also requires
them to be aware of potential definition conflicts. In practice,
definition conflicts are rare and often indicate misconfigurations. This
can be very useful as it is a good thing if misconfigurations are caught
early.

Applications declare the AMQP entities that they need, define necessary
routing schemes and may choose to delete AMQP entities when they are no
longer used.

AMQP Exchanges and Exchange Types
---------------------------------

*Exchanges* are AMQP entities where messages are sent. Exchanges then
take a message and route it into one or more (or no) queues. The routing
algorithm used depends on *exchange type* and rules called *bindings*.
AMQP 0.9.1 brokers typically provide 4 exchange types out of the box:

 * Direct exchange (typically used for for 1-to-1 communication or
unicasting)
 * Fanout exchange (1-to-n communication or broadcasting)
 * Topic exchange (1-to-n or n-to-m communication, multicasting)
 * Headers exchange (message metadata-based routing)

but it is possible to extend AMQP 0.9.1 brokers with custom exchange
types, for example:

 * x-random exchange (randomly chooses a queue to route incoming
messages to)
 * x-recent-history (a fanout exchange that also keeps N recent
messages in memory)
 * regular expressions based variations of headers exchange

and so on.

Besides the type, exchanges have a number of attributes, most important
of which are:

 * Name
 * Can be durable (information about them is persisted to disk and thus
survives broker restarts) or non-durable (information is only kept in
RAM)
 * Can have metadata associated with them on declaration

AMQP Queues
-----------

Queues in the AMQP Model are very similar to queues in other message and
“task queueing” systems: they store messages that are consumed by
applications. Like AMQP exchanges, an AMQP queue has a name and a
durability property but also

 * Can be exclusive (used by only one connection)
 * Can be automatically deleted when last consumer unsubscribes
 * Can have metadata associated with them on declaration (some brokers
use this to implement features like message TTL)

AMQP Bindings
-------------

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

Having this layer of indirection enables routing scenarios that are
impossible or very hard to implement using publishing directly to queues
and also eliminates a certain amount of duplicated work that application
developers have to do.

If an AMQP message cannot be routed to any queue (for example, because
there are no bindings for the exchange it was published to), it is
either dropped or returned to the publisher, depending on the message
attributes that the publisher has set.

AMQP Message Consumers
----------------------

Storing messages in queues is useless unless applications can *consume*
them. In the AMQP 0.9.1 Model, there are two ways for applications to do
this:

 * Have messages pushed to them (“push API”)
 * Fetch messages as needed (“pull API”)

With the “push API”, applications have to indicate interest in consuming
messages from a particular queue. When they do so, we say that they
*register a consumer* or, simply put, *subscribe to a queue*. It is
possible to have more than one consumer per queue or to register an
*exclusive consumer* (excludes all other consumers from the queue while
it is consuming).

Each consumer (subscription) has an identifier called a *consumer tag*.
This can be used to unsubscribe from messages. Consumer tags are just
strings.

AMQP Message Attributes and Payload
-----------------------------------

Messages in the AMQP Model have *attributes*. Some attributes are so
common that the AMQP 0.9.1 specification defines them and application
developers do not have to think about the exact attribute name. Some
examples are

 * Content type
 * Content encoding
 * Routing key
 * Delivery mode (persistent or not)
 * Message priority
 * Message publishing timestamp
 * Expiration period
 * Producer application id

Some attributes are used by AMQP brokers, but most are open to
interpretation by applications that receive them. Some attributes are
optional and known as *headers*. They are similar to X-Headers in HTTP.
Message attributes are set when a message is published.

AMQP messages also have a *payload* (the data that they carry). Brokers
treat this data as opaque (it is neither modified nor used by them). It
is possible for messages to contain only attributes and no payload. It
is common to use serialization formats like JSON, Thrift, Protocol
Buffers and MessagePack to serialize structured data in order to publish
it as an AMQP message payload.

AMQP Message Acknowledgements
-----------------------------

Since networks are unreliable and applications fail, it is often
necessary to have some kind of “processing acknowledgement”. Sometimes
it is only necessary to acknowledge the fact that a message has been
received. Sometimes acknowledgements mean that a message was validated
and processed by a consumer, for example, verified as having mandatory
data and persisted to a data store or indexed.

This situation is very common, so AMQP 0.9.1 has a built-in feature
called *message acknowledgements* (sometimes referred to as *acks*) that
consumers use to confirm message delivery and/or processing. If an
application crashes (the AMQP broker notices this when the connection is
closed), and if an acknowledgement for a message was expected but not
received by the AMQP broker, the message is re-queued (and possibly
immediately delivered to another consumer, if any exists).

Having acknowledgements built into the protocol helps developers to
build more robust software.

AMQP 0.9.1 Methods
------------------

AMQP 0.9.1 is structured as a number of *methods*. Methods are
operations (like HTTP methods) and have nothing in common with methods
in object-oriented programming languages. AMQP methods are grouped into
*classes*. Classes are just logical groupings of AMQP methods. The [AMQP
0.9.1 reference](http://www.rabbitmq.com/amqp-0-9-1-reference.html) can
be found on the RabbitMQ website.

Let us take a look at the `exchange.*` class, a group of methods
related to operations on exchanges. It includes the following
operations:

 * exchange.declare
 * exchange.declare-ok
 * exchange.delete
 * exchange.delete-ok

The operations above form logical pairs: **exchange.declare** and
**exchange.declare-ok**, **exchange.delete** and **exchange.delete-ok**.
These operations are “requests” and “responses” .

As an example, the client asks the broker to declare a new exchange
using the **exchange.declare** method:

![](https://img.skitch.com/20110720-c4qjdhmdrih9bn56npqnic4die.jpg)

As shown on the diagram above, **exchange.declare** carries
several*parameters*. They enable the client to specify exchange name,
type, durability flag and so on.

If the operation succeeds, the broker responds with the
**exchange.declare-ok** method:

![](https://img.skitch.com/20110720-m4ptjbnex2sa52g6wdwj3e9ahm.jpg)

**exchange.declare-ok** does not carry any parameters except for the
channel number.

The sequence of events is very similar for another method pair,
**queue.declare** and **queue.declare-ok**:

![](https://img.skitch.com/20110720-tmxswrie71ubb5m5nh8n17idhk.jpg)

![](https://img.skitch.com/20110720-g67urxg75c71qtwhwsjs684323.jpg)

Not all AMQP methods have counterparts. Some do not have corresponding
“response” methods and some others have more than one possible
“response”.

## AMQP Connections

AMQP connections are typically long-lived. AMQP is an application level
protocol that uses TCP for reliable delivery. AMQP connections use
authentication and can be protected using TLS . When an application no
longer needs to be connected to an AMQP broker, it should gracefully
close the AMQP connection instead of abruptly closing the underlying TCP
connection.

## AMQP Channels

Some applications need multiple connections to an AMQP broker. However,
it is undesirable to keep many TCP connections open at the same time
because doing so consumes system resources and makes it more difficult
to configure firewalls. AMQP 0.9.1 connections are multiplexed
with*channels\_ that can be thought of as “lightweight connections that
share a single TCP connection”.

For applications that use multiple threads/processes/etc. for
processing, it is very common to open a new channel per thread (process,
etc.) and **not share** channels between them.

Communication on a particular channel is completely separate from
communication on another channel, therefore every AMQP method also
carries a channel number that clients use to figure out which channel
the method is for (and thus, which event handler needs to be invoked).

## AMQP Virtual Hosts (vhosts)

To make it possible for a single broker to host multiple isolated
“environments” (groups of users, exchanges, queues and so on), AMQP
includes the concept of *virtual hosts* (vhosts). They are similar to
virtual hosts used by many popular Web servers and provide completely
isolated environments in which AMQP entities live. AMQP clients specify
the vhosts that they want to use during AMQP connection negotiation.

An AMQP 0.9.1 vhost name can be any non-blank string. Some of the most
common use cases for vhosts are

 * To separate AMQP entities used by different groups of applications
 * To separate multiple installations/environments (e.g. production,
staging) of one or more applications
 * To implement a multi-tenant environment

## AMQP is Extensible

AMQP 0.9.1 has several extension points:

 * Custom exchange types let developers implement routing schemes that
exchange types provided out-of-the-box do not cover well, for example,
geodata-based routing.
 * Declaration of exchanges and queues can include additional
attributes that the broker can use. For example, per-queue message TTL
in RabbitMQ is implemented this way.
 * Broker-specific extensions to the protocol. See, for example,
[extensions RabbitMQ
implements](http://www.rabbitmq.com/extensions.html).
 * New AMQP 0.9.1 method classes can be introduced.
 * Brokers can be extended with additional plugins, for example,
RabbitMQ management frontend and HTTP API are implemented as a plugin.

These features make the AMQP 0.9.1 Model even more flexible and
applicable to a very broad range of problems.

## Key differences from some other messaging models

One key difference to understand about the AMQP 0.9.1 model is that
**messages are not sent to queues. They are sent to exchanges that route
them to queues according to rules called “bindings”**. This means that
routing is primarily handled by AMQP brokers and not applications
themselves.

TBD

## AMQP 0.9.1 clients ecosystem

### Overview

There are many AMQP 0.9.1 clients for popular programming languages and
platforms. Some of them follow AMQP terminology closely and only provide
implementations of AMQP methods. Some others have additional features,
convenience methods and abstractions. Some of the clients are
asynchronous (non-blocking), some are synchronous (blocking), some
support both models. Some clients support vendor-specific extensions
(for example, RabbitMQ-specific extensions).

Because one of the main AMQP goals is interoperability, it is a good
idea for developers to understand protocol operations and not limit
themselves to the terminology of a particular client library. This way
communicating with developers using different libraries will be
significantly easier.

## Wrapping up

This is the end of the AMQP 0.9.1 Model tutorial. Congratulations! Armed
with this knowledge, you will find it easier to follow the rest of the
amqp gem documentation as well as the rabbitmq.com documentation and the
[RabbitMQ mailing list](https://groups.google.com/forum/#!forum/rabbitmq-users).

To stay up to date with amqp gem development, [follow @rubyamqp on
Twitter](http://twitter.com/rubyamqp) and [join our mailing
list](http://groups.google.com/group/ruby-amqp).

## What to read next

Documentation is organized as a number of documentation guides, covering
all kinds of topics from [use cases for various exchange
types](/articles/working_with_exchanges/) to [error
handling](/articles/error_handling/) and [Broker-specific AMQP 0.9.1
extensions](/articles/broker_specific_extensions).

We recommend that you read the following guides next, if possible, in
this order:

 * [Connection to the broker](/articles/connecting_to_broker/). This
guide explains how to connect to an AMQP broker and how to integrate the
amqp gem into standalone and Web applications.
 * [Working With Queues](/articles/working_with_queues/). This guide
focuses on features that consumer applications use heavily.
 * [Working With Exchanges](/articles/working_with_exchanges/). This
guide focuses on features that producer applications use heavily.
 * [Patterns & Use Cases](/articles/patterns_and_use_cases/). This
guide focuses implementation of [common messaging
patterns](http://www.eaipatterns.com/) using AMQP Model features as
building blocks.
 * [Error Handling & Recovery](/articles/error_handling/). This guide
explains how to handle protocol errors, network failures and other
things that may go wrong in real world projects.

If you are migrating your application from earlier versions of the amqp
gem (0.6.x and 0.7.x), to 0.8.x and later, there is the [amqp gem 0.8
migration guide](/articles/08_migration/).
