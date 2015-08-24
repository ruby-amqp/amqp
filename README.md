# Ruby amqp gem: the asynchronous Ruby RabbitMQ client

[Ruby amqp gem](http://rubyamqp.info) is a feature-rich,
EventMachine-based RabbitMQ client with batteries included.

It implement [AMQP
0.9.1](http://www.rabbitmq.com/tutorials/amqp-concepts.html) and
support [RabbitMQ extensions to AMQP
0.9.1](http://www.rabbitmq.com/extensions.html).


## A Word of Warning: Use This Only If You Already Use EventMachine

Unless you **already use EventMachine**, there is no real reason to
use this client. Consider [Bunny](http://rubybunny.info) or [March Hare](http://rubymarchhare.info) instead.

amqp gem brings in a fair share of EventMachine complexity which
cannot be fully eliminated. Event loop blocking, writes that happen
at the end of loop tick, uncaught exceptions in event loop silently killing it:
it's not worth the pain unless you've already deeply invested in EventMachine
and understand how it works.

So, just use Bunny or March Hare. You will be much happier.


## I know what RabbitMQ is, how do I get started?

See [Getting started with amqp gem](http://rubyamqp.info/articles/getting_started/) and other [amqp gem documentation guides](http://rubyamqp.info/).
We recommend that you read [AMQP 0.9.1 Model Explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html), too.



## What is RabbitMQ?

RabbitMQ is an open source messaging middleware that emphasizes
interoperability between different technologies (for example, Java,
.NET, Ruby, Python, Node.js, Erlang, Go, C and so on).

Key features of RabbitMQ are very flexible yet simple routing and
binary protocol efficiency. RabbitMQ supports many sophisticated
features, for example, message acknowledgements, queue length limit,
message TTL, redelivery of messages that couldn't be processed, load
balancing between message consumers and so on.


## What is amqp gem good for?

One can use amqp gem to make Ruby applications interoperate with other
applications (both Ruby and not). Complexity and size may vary from
simple work queues to complex multi-stage data processing workflows that involve
dozens or hundreds of applications built with all kinds of technologies.

Specific examples:

 * Events collectors, metrics & analytics applications can aggregate events produced by various applications
   (Web and not) in the company network.

 * A Web application may route messages to a Java app that works
   with SMS delivery gateways.

 * MMO games can use flexible routing AMQP provides to propagate event notifications to players and locations.

 * Price updates from public markets or other sources can be distributed between interested parties, from trading systems to points of sale in a specific geographic region.

 * Content aggregators may update full-text search and geospatial search indexes
   by delegating actual indexing work to other applications over AMQP.

 * Companies may provide streaming/push APIs to their customers, partners
   or just general public.

 * Continuous integration systems can distribute builds between multiple machines with various hardware and software
   configurations using advanced routing features of AMQP.

 * An application that watches updates from a real-time stream (be it markets data
   or Twitter stream) can propagate updates to interested parties, including
   Web applications that display that information in the real time.



## Getting started with Ruby amqp gem

### Install RabbitMQ

Please refer to the [RabbitMQ installation guide](http://www.rabbitmq.com/install.html). Note that for Ubuntu and Debian we strongly advice that you
use [RabbitMQ apt repository](http://www.rabbitmq.com/debian.html#apt) that has recent versions of RabbitMQ. RabbitMQ packages Ubuntu and Debian ship
with are outdated even in recent (10.10) releases. Learn more in the [RabbitMQ versions guide](http://rubydoc.info/github/ruby-amqp/amqp/master/file/docs/RabbitMQVersions.textile).


### Install the gem

On Microsoft Windows 7

    gem install eventmachine
    gem install amqp

On other OSes

    gem install amqp


### "Hello, World" example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require 'amqp'

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connecting to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

  ch  = AMQP::Channel.new(connection)
  q   = ch.queue("amqpgem.examples.hello_world", :auto_delete => true)
  x   = ch.default_exchange

  q.subscribe do |metadata, payload|
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close {
      EventMachine.stop { exit }
    }
  end

  x.publish "Hello, world!", :routing_key => q.name
end
```


[Getting started guide](http://rubyamqp.info/articles/getting_started/) explains this and two more examples in detail,
and is written in a form of a tutorial. See [AMQP 0.9.1 Model Explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html) if you want
to learn more about RabbitMQ protocol principles & concepts.


## Supported Ruby Versions

This library works with

 * Ruby 2.1
 * Ruby 2.0
 * Ruby 1.9.3
 * [JRuby](http://jruby.org)
 * [Rubinius](http://rubini.us)
 * Ruby 1.9.2
 * Ruby 1.8.7
 * [REE](http://www.rubyenterpriseedition.com),



## Documentation: tutorials, guides & API reference

We believe that in order to be a library our users **really** love, we need to care about documentation as much as (or more)
code readability, API beauty and autotomated testing across 5 Ruby implementations on multiple operating systems. We do care
about our [documentation](http://rubyamqp.info): **if you don't find your answer in documentation, we consider it a high severity bug** that you
should [file to us](http://github.com/ruby-amqp/amqp/issues). Or just complain to [@rubyamqp](https://twitter.com/rubyamqp) on Twitter.


### Tutorials

[Getting started guide](http://rubyamqp.info/articles/getting_started/) is written as a tutorial that walks you through
3 examples:

 * The "Hello, world" of messaging, 1-to-1 communication
 * Blabbr, a Twitter-like example of broadcasting (1-to-many communication)
 * Weathr, an example of sophisticated routing capabilities AMQP 0.9.1 has to offer (1-to-many or many-to-many communication)

all in under 20 minutes. [AMQP 0.9.1 Concepts](http://www.rabbitmq.com/tutorials/amqp-concepts.html) will introduce you to protocol concepts
in less than 5 minutes.


### Guides

[Documentation guides](http://rubyamqp.info) describe the library itself as well as AMQP concepts, usage scenarios, topics like working with exchanges and queues,
error handing & recovery, broker-specific extensions, TLS support, troubleshooting and so on. Most of the documentation is in these guides.


### Examples

You can find many examples (both real-world cases and simple demonstrations) under [examples directory](https://github.com/ruby-amqp/amqp/tree/master/examples) in the repository.
Note that those examples are written against version 0.8.0.rc1 and later. 0.6.x and 0.7.x may not support certain AMQP protocol or "DSL syntax" features.

There is also a work-in-progress [Messaging Patterns and Use Cases With AMQP](http://rubyamqp.info/articles/patterns_and_use_cases/) documentation guide.


### API reference

[API reference](http://bit.ly/mDm1JE) is up on [rubydoc.info](http://rubydoc.info) and is updated daily.



## How to use AMQP gem with Ruby on Rails, Sinatra and other Web frameworks

We cover Web application integration for multiple Ruby Web servers in [Connecting to the broker guide](http://rubyamqp.info/articles/connecting_to_broker/).



## Community

 * Join also [RabbitMQ mailing list](https://groups.google.com/forum/#!forum/rabbitmq-users) (the AMQP community epicenter).
 * Join [Ruby AMQP mailing list](http://groups.google.com/group/ruby-amqp)
 * Follow [@rubyamqp](https://twitter.com/rubyamqp) on Twitter for Ruby AMQP ecosystem updates.
 * Stop by #rabbitmq on irc.freenode.net. You can use [Web IRC client](http://webchat.freenode.net?channels=rabbitmq) if you don't have IRC client installed.



## Maintainer Information

amqp gem is maintained by [Michael Klishin](http://twitter.com/michaelklishin).


## Continuous Integration

[![Continuous Integration status](https://secure.travis-ci.org/ruby-amqp/amqp.png?branch=master)](http://travis-ci.org/ruby-amqp/amqp)


## Links ##

* [API reference](http://rdoc.info/github/ruby-amqp/amqp/master/frames)
* [Documentation guides](http://rubyamqp.info)
* [Code Examples](https://github.com/ruby-amqp/amqp/tree/master/examples)
* [Issue tracker](http://github.com/ruby-amqp/amqp/issues)
* [Continous integration status](http://travis-ci.org/#!/ruby-amqp/amqp)


## License ##

amqp gem is licensed under the [Ruby License](http://www.ruby-lang.org/en/LICENSE.txt).



## Credits and copyright information ##

* The Original Code is [tmm1/amqp](http://github.com/tmm1/amqp).
* The Initial Developer of the Original Code is Aman Gupta.
* Copyright (c) 2008 - 2010 [Aman Gupta](http://github.com/tmm1).
* Contributions from [Jakub Stastny](http://github.com/botanicus) are Copyright (c) 2011-2012 VMware, Inc.
* Copyright (c) 2010 — 2014 [ruby-amqp](https://github.com/ruby-amqp) group members.

Currently maintained by [ruby-amqp](https://github.com/ruby-amqp) group members
Special thanks to Dmitriy Samovskiy, Ben Hood and Tony Garnock-Jones.


## How can I learn more about AMQP and messaging in general? ##

### AMQP resources ###

 * [AMQP 0.9.1 Model Explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html)
 * [RabbitMQ tutorials](http://www.rabbitmq.com/getstarted.html) that demonstrate interoperability
 * [Wikipedia page on AMQP](http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol)
 * [AMQP quick reference](http://www.rabbitmq.com/amqp-0-9-1-quickref.html)
 * John O'Hara on the [history of AMQP](http://www.acmqueue.org/modules.php?name=Content&pa=showpage&pid=485)

### Messaging and distributed systems resources ###

 * [Enterprise Integration Patterns](http://www.eaipatterns.com), a book about messaging and use of messaging in systems integration.
 * [A Critique of the Remote Procedure Call Paradigm](http://www.cs.vu.nl/~ast/publications/euteco-1988.pdf)
 * [A Note on Distributed Computing](http://research.sun.com/techrep/1994/smli_tr-94-29.pdf)
 * [Convenience Over Correctness](http://steve.vinoski.net/pdf/IEEE-Convenience_Over_Correctness.pdf)
 * Joe Armstrong on [Erlang messaging vs RPC](http://armstrongonsoftware.blogspot.com/2008/05/road-we-didnt-go-down.html)




[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/ruby-amqp/amqp/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

