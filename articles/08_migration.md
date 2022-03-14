---
title: "Upgrading to amqp gem 0.8.x and later versions"
layout: article
---

About this guide
----------------

This guide explains how (and why) applications that use amqp gem
versions 0.6.x and 0.7.x should migrate to 0.8.0 and future versions. It
also outlines deprecated features and when and why they will be removed.

This work is licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative
Commons Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
Github](https://github.com/ruby-amqp/rubyamqp.info).

Covered versions
----------------

This guide covers Ruby amqp gem 0.6.x and 0.7.x.

Brief history of amqp gem
-------------------------

The amqp gem was born in early July 2008. Since then, it has seen 7
releases, used by all kinds of companies, and has become a key component
in systems that process more than 100 gigabytes of data per day. Also,
despite not being a “1.0 library”, it has proven to be very usable.

For most of 2008 and 2009 the gem did not receive much of attention. In
2010, some other AMQP clients (for example, RabbitMQ Java & .NET
clients) switched to the AMQP 0.9.1 specification. By the fall of 2010
it had become clear that the amqp gem needed a new team of maintainers,
deep refactoring, new solid test suite and extensive documentation
guides. Long story short, by December 2010, the [new maintainers
group](https://github.com/ruby-amqp) was formed and now maintains a
number of other libraries in the Ruby AMQP ecosystem, most notably the
[Bunny gem](github.com/ruby-amqp/bunny).

Over the first few months of 2011, the amqp gem underwent a number of
maintenance releases (known as the 0.7.x series), a ground up rewrite of
the test suite, major documentation update as well as a major
refactoring. It was upgraded to the AMQP 0.9.1 specification and based
on a new, much more efficient AMQP serialization library,
[amq-protocol](https://github.com/ruby-amqp/amq-protocol).

As part of this transition, the amqp gem maintainers team pursued a
number of goals:

 * Implement the AMQP 0.9.1 spec plus all of the RabbitMQ extensions
 * End the "300 of 1 patch forks" situation that had become especially bad
in early 2010
 * Produce a solid end-to-end test suite that imitates real
asynchronous applications
 * Resolve many API usability issues: inconsistent behavior, weird
class and method naming, heavy reliance on implicit connection objects
and so on
 * Produce documentation guides that other AMQP client users will be
envious of
 * Define a stable public API
 * Improve memory efficiency and performance
 * Resolve many limitations of the original API and implementation
design
 * Drop all of the "experimental-stuff-that-was-never-finished"

In the end, several projects like
[evented-spec](https://github.com/ruby-amqp/evented-spec) were born and
became part of the amqp gem family of libraries. The "300 one patch
forks" hell is a thing of the past. Even the initial pure Ruby
implementation of the new serialization library was [several times as
memory
efficient](http://www.rabbitmq.com/blog/2011/03/01/ruby-amqp-benchmarks/)
as the original one. The response to the [Documentation
guides](http://bit.ly/amqp-gem-docs) response was very positive.
amqp gem 0.8.0 implemented all but one RabbitMQ extension as well as
AMQP 0.9.1 spec features that the original gem never fully implemented.
Many heavy users of the gem upgraded to 0.8 or later versions. The future for
the amqp gem and its spin-offs is bright.

amqp gem 0.8.0 backwards compatibility policy
---------------------------------------------

amqp gem 0.8.0 is **not
100 backwards compatible*. That said, for most applications, the upgrade path is easy. Over 90
of the deprecated API classes and methods are still in place and will
only be dropped in the 0.9.0 release.

Plenty of the incompatibilities between the 0.6.x and 0.7.x series were
ironed out in 0.8.0. This guide will explain what has changed and
why. It will also encourage you to upgrade and show how you should adapt
your application code.

## Why developers should upgrade to 0.8.0

 * [Great documentation](http://rubyamqp.info)
 * amqp gem 0.8.0 and later versions are actively maintained
 * Most of the heaviest library users have either already switched to
amqp gem 0.8.0 or are switching in the near future
 * AMQP 0.9.1 spec implementation: many other popular clients, for
example the RabbitMQ Java client, has dropped support for the AMQP 0.8
specification
 * Support for RabbitMQ extensions
 * Applications that do not use deprecated API features and behaviors
will have a seamless upgrade path to amqp gem 0.9.0 and beyond

AMQP protocol version change
----------------------------

amqp gems before 0.8.0 (0.6.x, 0.7.x) series implemented (most of) the
AMQP 0.8 specification. amqp gem 0.8.0 implements AMQP 0.9.1 and thus
**requires RabbitMQ version 2.0 or later**. See [RabbitMQ
versions](/articles/rabbitmq_versions/) for more information about
RabbitMQ versions support and how to obtain up-to-date packages for your
operating system.

<span class="note">
amqp gem 0.8.0 and later versions implement AMQP 0.9.1 and thus
**require RabbitMQ version 2.0 or later**
</span>

Follow established AMQP terminology
-----------------------------------

### require “mq” is deprecated

Instead of the following:

``` ruby
require "amqp"
require "mq"
```

or

``` ruby
require "mq"
```

switch to

``` ruby
require "amqp"
```

<span class="note">
mq.rb will be removed before 1.0 release.
</span>

### MQ class is deprecated

Please use `AMQP::Channel` instead. MQ class and its
methods are implemented in amqp gem 0.8.x for backwards compatibility.

Why is it deprecated? Because it was a poor name choice. Both mq.rb and
the MQ class depart from AMQP terminology and make eight out of ten
engineers think that they have something to do with AMQP queues (in
fact, MQ should have been called Channel in the first place). No other
RabbitMQ client library that we know of invents its own terminology when it
comes to protocol entities and the amqp gem shouldn’t either.

<span class="note">
The MQ class and class methods that use an implicit connection (MQ.queue
and so on) will be removed before the 1.0 release.
</span>

MQ class is now AMQP::Channel
-----------------------------

The MQ class was renamed to AMQP::Channel to follow the established
[AMQP 0.9.1 terminology](/articles/amqp_9_1_model_explained/). Implicit
per-thread channels are deprecated:

``` ruby
# amqp gem 0.6.x code style: connection is implicit, channel is implicit. Error handling and recovery are thus
# not possible.
# Deprecated, do not use.
MQ.queue("search.indexing")

# same for exchanges. Deprecated, do not use.
MQ.direct("services.imaging")
MQ.fanout("services.broadcast")
MQ.topic("services.weather_updates")

# connection object lets you define error handlers
connection = AMQP.connect(:vhost => "myapp/production", :host => "192.168.0.18")
# channel object lets you define error handlers and use multiple channels per application,
# for example, one per thread
channel    = AMQP::Channel.new(connection)
# AMQP::Channel#queue remains unchanged otherwise
channel.queue("search.indexing")

# exchanges examples
channel.direct("services.imaging")
channel.fanout("services.broadcast")
channel.topic("services.weather_updates")
```

<span class="note">
MQ.queue, MQ.direct, MQ.fanout and MQ.topic methods will be removed
before 1.0 release. Use
instance methods on AMQP::Channel (AMQP::Channel#queue,
AMQP::Channel#direct, AMQP::Channel#default_exchange
and so on) instead.
</span>

MQ::Queue is now AMQP::Queue
----------------------------

MQ::Queue is now AMQP::Queue. All the methods from 0.6.x series are
still available.

<span class="note">
MQ::Queue alias will be removed before 1.0 release. Please switch to
AMQP::Queue.
</span>

MQ::Exchange is now AMQP::Exchange
----------------------------------

MQ::Exchange is now AMQP::Exchange. All of the methods from the 0.6.x
series are still available.

<span class="note">
MQ::Exchange alias will be removed before 1.0 release. Please switch to
AMQP::Exchange.
</span>

MQ::Header is now AMQP::Header
------------------------------

MQ::Header is now AMQP::Header. If your code has any type checks or case
matches on MQ::Header, it needs to change to AMQP::Header.

AMQP.error is deprecated
------------------------

Catch-all solutions for error handling are very difficult to use.
Automatic recovery and fine-grained event handling is also not possible.
amqp gem 0.8.0 and later includes a fine-grained [Error Handling
and Recovery API](/articles/error_handling/) that is significantly
easier to use in real-world cases but also makes automatic recovery mode
possible.

<span class="note">
AMQP.error method will be removed before 1.0 release.
</span>

MQ::RPC is deprecated
---------------------

It was an experiment that was never finished. Some API design choices
are very opinionated as well. The amqp gem should not ship with
half-baked poorly designed or overly opinionated solutions.

<span class="note">
MQ::RPC class will be removed before 1.0 release.
</span>

MQ::Logger is removed
---------------------

It was another experiment that was never finished.

<span class="note">
MQ::Logger class was removed in the the amqp gem 0.8.0 development
cycle.
</span>

AMQP::Buffer is removed
-----------------------

AMQP::Buffer was an AMQP 0.8 protocol implementation detail. With the
new [amq-protocol gem](http://rubygems.org/gems/amq-protocol), it is no
longer required.

<span class="note">
AMQP::Buffer class was removed in the the amqp gem 0.8.0 development
cycle.
</span>

AMQP::Frame is removed
----------------------

AMQP::Frame was an AMQP 0.8 protocol implementation detail. With the new
[amq-protocol gem](http://rubygems.org/gems/amq-protocol), it is no
longer required.

<span class="note">
AMQP::Frame class was removed in the the amqp gem 0.8.0 development
cycle.
</span>

AMQP::Server is removed
-----------------------

AMQP::Server was (an unfinished) toy implementation of AMQP 0.8 broker
in Ruby on top of EventMachine. We believe that Ruby is not an optimal
choice for AMQP broker implementations. We also never heard of anyone
using it.

<span class="note">
AMQP::Server class was removed in the amqp gem 0.8.0 development cycle.
</span>

AMQP::Protocol::* classes are removed
--------------------------------------

AMQP::Protocol::* classes were an AMQP 0.8 protocol implementation
detail. With the new [amq-protocol
gem](http://rubygems.org/gems/amq-protocol), they are no longer
required.

<span class="note">
AMQP::Protocol::* classes were removed in the the amqp gem 0.8.0
development cycle.
</span>
