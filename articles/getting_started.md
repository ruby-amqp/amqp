---
title: "Getting Started with RabbitMQ and Ruby Using amqp gem"
layout: article
---

## About this guide

This guide is a quick tutorial that helps you to get started with
RabbitMQ and the [Ruby amqp gem](http://github.com/ruby-amqp/amqp).
It should take about 20 minutes to read and study the provided code
examples. This guide covers:

 * Installing RabbitMQ, a mature popular server implementation of the AMQP protocol.
 * Installing the amqp gem via [Rubygems](http://rubygems.org) and [Bundler](http://gembundler.com).
 * Running a "Hello, world" messaging example that is a simple demonstration of 1:1 communication.
 * Creating a "Twitter-like" publish/subscribe example with one publisher and four subscribers that demonstrates 1:n communication.
 * Creating a topic routing example with two publishers and eight subscribers showcasing n:m communication when subscribers only receive messages that they are interested in.
 * Learning how the amqp gem can be integrated with Ruby objects in a way that makes unit testing easy.

This work is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/3.0/">Creative Commons
Attribution 3.0 Unported License</a> (including images and
stylesheets).  The source is available [on
GitHub](https://github.com/ruby-amqp/rubyamqp.info).


## Which versions of the amqp gem does this guide cover?

This guide covers Ruby amqp gem 1.7.0 and later versions.


## Installing RabbitMQ

The [RabbitMQ site](http://rabbitmq.com) has a good [installation guide](http://www.rabbitmq.com/install.html) that addresses many operating systems.
On Mac OS X, the fastest way to install RabbitMQ is with [Homebrew](http://mxcl.github.com/homebrew):

    brew install rabbitmq

then run it:

    rabbitmq-server

On Debian and Ubuntu, you can either [download the RabbitMQ .deb
package](http://www.rabbitmq.com/server.html) and install it with
[dpkg](http://www.debian.org/doc/FAQ/ch-pkgtools.en.html) or make use
of the [apt repository](http://www.rabbitmq.com/debian.html#apt) that
the RabbitMQ team provides.

For RPM-based distributions like RedHat or CentOS, the RabbitMQ team
provides an [RPM package](http://www.rabbitmq.com/install.html#rpm).

<div class="alert alert-error"><strong>Note:</strong> The RabbitMQ
package that ships with some popular Ubuntu versions (for example,
10.04 and 10.10) is outdated and *will not work with amqp gem 0.8.0
and later versions* (you will need at least RabbitMQ v2.0 for use with
this guide).</div>

## Installing the Ruby amqp gem

### Make sure that you have Ruby and [Rubygems](http://docs.rubygems.org/read/chapter/3) installed

This guide assumes that you have installed one of the following
supported Ruby implementations:

 * CRuby v2.4
 * CRuby v2.3
 * CRuby v2.2
 * CRuby v2.1
 * CRuby v2.0

### You can use Rubygems to install the amqp gem

#### On Microsoft Windows 7:

    gem install eventmachine
    gem install amqp

#### On other OSes or JRuby:

    gem install amqp

### You can also use Bundler to install the gem

```ruby
source "https://rubygems.org"
gem "amqp", "~> 1.7.0"
```

### Verifying your installation

Verify your installation with a quick irb session:

```
irb -rubygems
:001 > require "amqp"
=> true
:002 > AMQP::VERSION
=> "1.7.0"
```

## "Hello, world" example

Let us begin with the classic "Hello, world" example. First, here is the code:

```ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."

  channel  = AMQP::Channel.new(connection)
  queue    = channel.queue("amqpgem.examples.helloworld", :auto_delete => true)
  exchange = channel.direct("")

  queue.subscribe do |payload|
    puts "Received a message: #{payload}. Disconnecting..."
    connection.close { EventMachine.stop }
  end

  exchange.publish "Hello, world!", :routing_key => queue.name
end
```

This example demonstrates a very common communication scenario: *application A* wants to publish a message that will end up in a queue that *application B* listens on. In this case, the queue name is "amqpgem.examples.hello". Let us go through the code step by step:

```ruby
require "rubygems"
require "amqp"
```

is the simplest way to load the amqp gem if you have installed it with RubyGems, but remember that you can omit the rubygems line if your environment does not need it. The following piece of code

```ruby
EventMachine.run do
  # ...
end
```

runs what is called the [EventMachine](http://rubyeventmachine.com)
reactor. We will not go into what the term 'reactor' means here, but
suffice it to say that the amqp gem is asynchronous and is based on an
asynchronous network I/O library called _EventMachine_.

The next line

```ruby
connection = AMQP.connect(:host => '127.0.0.1')
```

connects to the server running on localhost, with the default port (5672), username (guest), password (guest) and virtual host ('/').

The next line

```ruby
channel  = AMQP::Channel.new(connection)
```

opens a new _channel_. AMQP is a multi-channeled protocol that uses channels to multiplex a TCP connection.

Channels are opened on a connection, therefore the `AMQP::Channel` constructor takes a connection object as a parameter.

This line

```ruby
queue    = channel.queue("amqpgem.examples.helloworld", :auto_delete => true)
```

declares a _queue_ on the channel that we have just opened. Consumer applications get messages from queues. We declared this queue with the "auto-delete" parameter. Basically, this means that the queue will be deleted when there are no more processes consuming messages from it.

The next line

```ruby
exchange = channel.direct("")
```

instantiates an _exchange_. Exchanges receive messages that are sent
by producers. Exchanges route messages to queues according to rules
called _bindings_. In this particular example, there are no explicitly
defined bindings. The exchange that we defined is known as the
_default exchange_ and it has implied bindings to all queues. Before
we get into that, let us see how we define a handler for incoming
messages

```ruby
queue.subscribe do |payload|
  puts "Received a message: #{payload}. Disconnecting..."
  connection.close { EventMachine.stop }
end
```

`AMQP::Queue#subscribe` takes a block that will be called every time a message arrives. `AMQP::Session#close` closes the AMQP connection and runs a callback that stops the EventMachine reactor.

Finally, we publish our message

```ruby
exchange.publish "Hello, world!", :routing_key => queue.name
```

Routing key is one of the _message attributes_. The default exchange
will route the message to a queue that has the same name as the
message's routing key. This is how our message ends up in the
"amqpgem.examples.helloworld" queue.

This first example can be modified to use the method chaining technique:

```ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

EventMachine.run do
  AMQP.connect(:host => '127.0.0.1') do |connection|
    puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."

    channel  = AMQP::Channel.new(connection)

    channel.queue("amqpgem.examples.helloworld", :auto_delete => true).subscribe do |payload|
      puts "Received a message: #{payload}. Disconnecting..."

      connection.close { EventMachine.stop }
    end

    channel.direct("").publish "Hello, world!", :routing_key => "amqpgem.examples.helloworld"
  end
end
```

This diagram demonstrates the "Hello, world" example data flow:

!https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/001_hello_world_example_routing.png!

For the sake of simplicity, both the message producer (App I) and the
consumer (App II) are running in the same Ruby process. Now let us
move on to a little bit more sophisticated example.


## Blabblr: one-to-many publish/subscribe (pubsub) example

The previous example demonstrated how a connection to a broker is made and how to do 1:1 communication using the default exchange. Now let us take a look at another common scenario: broadcast, or multiple consumers and one producer.

A very well-known broadcast example is Twitter: every time a person
tweets, followers receive a notification. Blabbr, our imaginary
information network, models this scenario: every network member has a
separate queue and publishes blabs to a separate exchange. Three
Blabbr members, Joe, Aaron and Bob, follow the official NBA account on
Blabbr to get updates about what is happening in the world of
basketball. Here is the code:

```ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

AMQP.start("amqp://127.0.0.1:5672") do |connection|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.fanout("nba.scores")

  channel.queue("joe", :auto_delete => true).bind(exchange).subscribe do |payload|
    puts "#{payload} => joe"
  end

  channel.queue("aaron", :auto_delete => true).bind(exchange).subscribe do |payload|
    puts "#{payload} => aaron"
  end

  channel.queue("bob", :auto_delete => true).bind(exchange).subscribe do |payload|
    puts "#{payload} => bob"
  end

  exchange.publish("BOS 101, NYK 89").publish("ORL 85, ALT 88")

  # disconnect & exit after 2 seconds
  EventMachine.add_timer(2) do
    exchange.delete

    connection.close { EventMachine.stop }
  end
end
```

The first line has a few differences from the "Hello, world" example above:

 * We use `AMQP.start` instead of `AMQP.connect`
 * Instead of return values, we pass a block to the connection method and it yields a connection
   object back as soon as the connection is established.
 * Instead of passing connection parameters as a hash, we use a URI string.

`AMQP.start` is just a convenient way to do

```ruby
EventMachine.run do
  AMQP.connect(options) do |connection|
    # ...
  end
end
```

The `AMQP.start` call blocks the current thread which
means that its use is limited to scripts and small command line
applications. Blabbr is just that.

`AMQP.connect`, when invoked with a block, will yield a
connection object as soon as the AMQP connection is open. Finally,
connection parameters may be supplied as a Hash or as a connection
string. The `AMQP.connect` method documentation contains all of the
details.

In this example, opening a channel is no different to opening a
channel in the previous example, however, the exchange is declared
differently

```ruby
exchange = channel.fanout("nba.scores")
```

The exchange that we declare above using `AMQP::Channel#fanout` is a _fanout exchange_. A fanout exchange delivers messages to all of the queues that are bound to it: exactly what we want in the case of Blabbr!

This piece of code

```ruby
channel.queue("joe", :auto_delete => true).bind(exchange).subscribe do |payload|
  puts "#{payload} => joe"
end
```

is similar to the subscription code that we used for message delivery previously, but what does that `AMQP::Queue#bind` method do? It sets up a binding between the queue and the exchange that you pass to it. We need to do this to make sure that our fanout exchange routes messages to the queues of any subscribed followers.

```ruby
exchange.publish("BOS 101, NYK 89").publish("ORL 85, ALT 88")
```

demonstrates `AMQP::Exchange#publish` call chaining. Blabbr members use a fanout exchange for publishing, so there is no need to specify a message routing key because every queue that is bound to the exchange will get its own copy of all messages, regardless of the queue name and routing key used.

A diagram for Blabbr looks like this:

!https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/002_blabbr_example_routing.png!


Next we use EventMachine's [add_timer](http://eventmachine.rubyforge.org/EventMachine.html#M000466) method to run a piece of code in 1 second from now:

```ruby
EventMachine.add_timer(1) do
  exchange.delete
  connection.close { EventMachine.stop }
end
```

The code that we want to run deletes the exchange that we declared earlier using `AMQP::Exchange#delete` and closes the AMQP connection with `AMQP::Session#close`. Finally, we stop the EventMachine event loop and exit.

Blabbr is pretty unlikely to secure hundreds of millions of dollars in funding, but it does a pretty good job of demonstrating how one can use AMQP fanout exchanges to do broadcasting.

## Weathr: many-to-many topic routing example

So far, we have seen point-to-point communication and broadcasting. Those two communication styles are possible with many protocols, for instance, HTTP handles these scenarios just fine. You may ask "what differentiates AMQP?" Well, next we are going to introduce you to _topic exchanges_ and routing with patterns, one of the features that makes AMQP very powerful.

Our third example involves weather condition updates. What makes it different from the previous two examples is that not all of the consumers are interested in all of the messages. People who live in Portland usually do not care about the weather in Hong Kong (unless they are visiting soon). They are much more interested in weather conditions around Portland, possibly all of Oregon and sometimes a few neighbouring states.

Our example features multiple consumer applications monitoring updates for different regions. Some are interested in updates for a specific city, others for a specific state and so on, all the way up to continents. Updates may overlap so that an update for San Diego, CA appears as an update for California, but also should show up on the North America updates list.

Here is the code:

```ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "amqp"

EventMachine.run do
  AMQP.connect do |connection|
    channel  = AMQP::Channel.new(connection)
    # topic exchange name can be any string
    exchange = channel.topic("weathr", :auto_delete => true)

    # Subscribers.
    channel.queue("", :exclusive => true) do |queue|
      queue.bind(exchange, :routing_key => "americas.north.#").subscribe do |headers, payload|
        puts "An update for North America: #{payload}, routing key is #{headers.routing_key}"
      end
    end
    channel.queue("americas.south").bind(exchange, :routing_key => "americas.south.#").subscribe do |headers, payload|
      puts "An update for South America: #{payload}, routing key is #{headers.routing_key}"
    end
    channel.queue("us.california").bind(exchange, :routing_key => "americas.north.us.ca.*").subscribe do |headers, payload|
      puts "An update for US/California: #{payload}, routing key is #{headers.routing_key}"
    end
    channel.queue("us.tx.austin").bind(exchange, :routing_key => "#.tx.austin").subscribe do |headers, payload|
      puts "An update for Austin, TX: #{payload}, routing key is #{headers.routing_key}"
    end
    channel.queue("it.rome").bind(exchange, :routing_key => "europe.italy.rome").subscribe do |headers, payload|
      puts "An update for Rome, Italy: #{payload}, routing key is #{headers.routing_key}"
    end
    channel.queue("asia.hk").bind(exchange, :routing_key => "asia.southeast.hk.#").subscribe do |headers, payload|
      puts "An update for Hong Kong: #{payload}, routing key is #{headers.routing_key}"
    end

    EventMachine.add_timer(1) do
      exchange.publish("San Diego update", :routing_key => "americas.north.us.ca.sandiego").
        publish("Berkeley update",         :routing_key => "americas.north.us.ca.berkeley").
        publish("San Francisco update",    :routing_key => "americas.north.us.ca.sanfrancisco").
        publish("New York update",         :routing_key => "americas.north.us.ny.newyork").
        publish("São Paolo update",        :routing_key => "americas.south.brazil.saopaolo").
        publish("Hong Kong update",        :routing_key => "asia.southeast.hk.hongkong").
        publish("Kyoto update",            :routing_key => "asia.southeast.japan.kyoto").
        publish("Shanghai update",         :routing_key => "asia.southeast.prc.shanghai").
        publish("Rome update",             :routing_key => "europe.italy.roma").
        publish("Paris update",            :routing_key => "europe.france.paris")
    end


    show_stopper = Proc.new {
      connection.close { EventMachine.stop }
    }

    EventMachine.add_timer(2, show_stopper)
  end
end
```

The first line that is different from the Blabbr example is

```ruby
exchange = channel.topic("weathr", :auto_delete => true)
```

We use a topic exchange here. Topic exchanges are used for [multicast](http://en.wikipedia.org/wiki/Multicast) messaging where consumers indicate which topics they are interested in (think of it as subscribing to a feed for an individual tag in your favourite blog as opposed to the full feed). Routing with a topic exchange is done by specifying a _routing pattern_ on binding, for example:

```ruby
channel.queue("americas.south").bind(exchange, :routing_key => "americas.south.#").subscribe do |headers, payload|
  puts "An update for South America: #{payload}, routing key is #{headers.routing_key}"
end
```

Here we bind a queue with the name of "americas.south" to the topic exchange declared earlier using the `AMQP::Queue#bind` method.  This means that only messages with a routing key matching "americas.south.#" will be routed to that queue. A routing pattern consists of several words separated by dots, in a similar way to URI path segments joined by slashes. Here are a few examples:

 * asia.southeast.thailand.bangkok
 * sports.basketball
 * usa.nasdaq.aapl
 * tasks.search.indexing.accounts

Now let us take a look at a few routing keys that match the "americas.south.#" pattern:

 * americas.south
 * americas.south.*brazil*
 * americas.south.*brazil.saopaolo*
 * americas.south.*chile.santiago*

In other words, the "#" part of the pattern matches 0 or more words.

For a pattern like "americas.south.*", some matching routing keys would be:

 * americas.south.*brazil*
 * americas.south.*chile*
 * americas.south.*peru*

but not

 * americas.south
 * americas.south.chile.santiago

so "*" only matches a single word. The AMQP 0.9.1 specification says that topic segments (words) may contain the letters A-Z and a-z and digits 0-9.

A (very simplistic) diagram to demonstrate topic exchange in action:

!https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/003_weathr_example_routing.png!


One more thing that is different from previous examples is that the block we pass to `AMQP::Queue#subscribe` now takes two arguments: a _header_ and a _body_ (often called the _payload_). Long story short, the header parameter lets you access metadata associated with the message. Some examples of message metadata attributes are:

 * message content type
 * message content encoding
 * message priority
 * message expiration time
 * message identifier
 * reply to (specifies which message this is a reply to)
 * application id (identifier of the application that produced the message)

and so on.

As the following binding demonstrates, "#" and "*" can also appear at the beginning of routing patterns:

```ruby
channel.queue("us.tx.austin").bind(exchange, :routing_key => "#.tx.austin").subscribe do |headers, payload|
  puts "An update for Austin, TX: #{payload}, routing key is #{headers.routing_key}"
end
```

For this example the publishing of messages is no different from that of previous examples. If we were to run the program, a message published with a routing key of "americas.north.us.ca.berkeley" would be routed to 2 queues: "us.california" and the _server-named queue_ that we declared by passing a blank string as the name:

```ruby
channel.queue("", :exclusive => true) do |queue|
  queue.bind(exchange, :routing_key => "americas.north.#").subscribe do |headers, payload|
    puts "An update for North America: #{payload}, routing key is #{headers.routing_key}"
  end
end
```

The name of the server-named queue is generated by the broker and sent
back to the client with a queue declaration confirmation. Because the
queue name is not known before the reply arrives, we pass
`AMQP::Channel#queue` a callback and it yields us back a queue object
once confirmation has arrived.


### Avoid race conditions

A word of warning: you may find examples on the Web of `AMQP::Channel#queue` usage that do not use callbacks. We *recommend
that you use a callback for server-named queues*, otherwise your code
may be subject to [race
conditions](http://en.wikipedia.org/wiki/Race_condition). Even though
the amqp gem tries to be reasonably smart and protect you from most
common problems (for example, binding operations will be delayed until
after queue name is received from the broker), there is no way it can
do so for every case. The primary reason for supporting `AMQP::Channel#queue` usage without a callback for server-µnamed
queues is backwards compatibility with earlier versions of the gem.

## Integration with objects

Since Ruby is a genuine object-oriented language, it is important to demonstrate how the Ruby amqp gem can be integrated into rich object-oriented code.

The `AMQP::Queue#subscribe` callback does not have to be
a block. It can be any Ruby object that responds to `call`. A common
technique is to combine
[Object#method](http://rubydoc.info/stdlib/core/1.9.3/Object:method)
and
[Method#to_proc](http://rubydoc.info/stdlib/core/1.9.3/Method:to_proc)
and use object methods as message handlers.

An example to demonstrate this technique:

```ruby
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

The "Hello, world" example can be ported to use this technique:

```ruby
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

The most important line in this example is

```ruby
@queue.subscribe(&@consumer.method(:handle_message))
```

Ampersand (&) preceding an object is equivalent to calling the #to_proc method on it. We obtain a Consumer#handle_message method reference with

```ruby
@consumer.method(:handle_message)
```

and then the ampersand calls #to_proc on it. `AMQP::Queue#subscribe` then will be using this Proc instance to
handle incoming messages.

Note that the `Consumer` class above can be easily tested in isolation, without spinning up any AMQP connections.
Here is one example using [RSpec](http://relishapp.com/rspec)

```ruby
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


## Wrapping up

This is the end of the tutorial. Congratulations! You have learned quite a bit about both AMQP 0.9.1 and the amqp gem. This is only the tip of the iceberg. AMQP has many more features built into the protocol:

 * Reliable delivery of messages
 * Message confirmations (a way to tell broker that a message was or was not processed successfully)
 * Message redelivery when consumer applications fail or crash
 * Load balancing of messages between multiple consumers
 * Message metadata attributes

and so on. Other guides explain these features in depth, as well as use cases for them. To stay up to date with amqp gem development, [follow @rubyamqp on Twitter](http://twitter.com/rubyamqp) and [join our mailing list](http://groups.google.com/group/ruby-amqp).

## What to read next

Documentation is organized as a number of <a href="/">documentation guides</a>, covering all kinds of topics from [use cases for various exchange types](/articles/working_with_exchanges/) to [error handling](/articles/error_handling/) and [Broker-specific AMQP 0.9.1 extensions](/articles/broker_specific_extensions/).

We recommend that you read the following guides next, if possible, in this order:

 * [AMQP 0.9.1 Model Explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html). A simple 2 page long introduction to the AMQP Model concepts and features. Understanding the AMQP Model
   will make a lot of other documentation, both for the Ruby amqp gem and RabbitMQ itself, easier to follow. With this guide, you don't have to waste hours of time reading the whole specification.
 * [Connection to the broker](/articles/connecting_to_broker/). This guide explains how to connect to an AMQP broker and how to integrate the amqp gem into standalone and Web applications.
 * [Working With Queues](/articles/working_with_queues/). This guide focuses on features that consumer applications use heavily.
 * [Working With Exchanges](/articles/working_with_exchanges/). This guide focuses on features that producer applications use heavily.
 * [Patterns & Use Cases](/articles/patterns_and_use_cases/). This guide focuses implementation of [common messaging patterns](http://www.eaipatterns.com/) using AMQP Model features as building blocks.
 * [Error Handling & Recovery](/articles/error_handling/). This guide explains how to handle protocol errors, network failures and other things that may go wrong in real world projects.

If you are migrating your application from earlier versions of the
amqp gem (0.6.x and 0.7.x), to 0.8.x and later, there is the [amqp gem
0.8 migration guide](/articles/08_migration/).
