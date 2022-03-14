---
title: "Patterns and Use Cases"
layout: article
---

## About this guide

This guide explains typical messaging patterns and use cases. It only
covers the most common scenarios. For a comprehensive list of messaging
patterns, consult books on this subject, for example, [Enterprise
Integration Patterns](http://www.eaipatterns.com).

This work is licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative
Commons Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
Github](https://github.com/ruby-amqp/rubyamqp.info).

## Covered versions

This guide covers Ruby amqp gem 1.7.0 and later versions.

## Introduction

Messaging patterns are a lot like object-oriented design patterns in
that they are generalized reusable solutions to specific problems. They
are not recipes, however, and their exact implementation may vary from
application to application. Just like OO design patterns, they too can
be classified:
 * Message construction patterns describe form, content and purpose of
messages.
 * Message routing patterns outline how messages can be directed from
producers to consumers.
 * Message transformation patterns change message content or metadata.
There are other, more specialized groups of messaging patterns that are
out of the scope of this guide.
This guide demonstrates the implementation of several common routing
patterns and also explains how built-in AMQP 0.9.1 features can be used
to implement message construction and message transformation patterns.
Note that the guide is a work in progress. There are many messaging
patterns and new variations are being discovered every year. This guide
thus strives to be useful to the
80 of developers instead of being "complete".


## Request/Reply pattern

### Description and Use cases

Request/Reply is a simple way of integration when one application issues a request and another application responds to it. This pattern is often referred to as "Remote Procedure Call", even when it is not entirely correct. The Request/Reply pattern is a 1:1 communication pattern.
Some examples of the Request/Reply pattern are:
 * Application 1 requests a document that the Application 2 generates or loads and returns.
 * An end-user application issues a search request and another application returns the results.
 * One application requests a progress report from another application.

### RabbitMQ-based implementation

Implementation of Request/Reply pattern on top of AMQP 0.9.1 involves two messages: a request (Req) and a response (Res). A client app generates a request identifier and sets the :message_id attribute on Req. The client also uses a server-named exclusive queue to receive replies and thus sets the :reply_to Req attribute to the name of that queue.

A server app uses a well-known queue name to receive requests and sets the :correlation_id to the :message_id of the original request message (Req) to make it possible for the client to identify which request a reply is for.

#### Request message attributes

<dl>
  <dt>:message_id</dt>
  <dd>Unique message identifier</dd>
  <dt>:reply_to</dt>
  <dd>Queue name server should send the response to</dd>
</dl>

#### Response message attributes

<dl>
  <dt>:correlation_id</dt>
  <dd>Identifier of the original request message (set to request's :correlation_id)</dd>
  <dt>:routing_key</dt>
  <dd>Client's replies queue name (set to request's :reply_to)</dd>
</dl>

### Code example

#### Client code

``` ruby
require "amqp"

EventMachine.run do
  connection = AMQP.connect
  channel    = AMQP::Channel.new(connection)

  replies_queue = channel.queue("", :exclusive => true, :auto_delete => true)
  replies_queue.subscribe do |metadata, payload|
    puts "[response] Response for #{metadata.correlation_id}: #{payload.inspect}"
  end

  # request time from a peer every 3 seconds
  EventMachine.add_periodic_timer(3.0) do
    puts "[request] Sending a request..."
    channel.default_exchange.publish("get.time",
                                     :routing_key => "amqpgem.examples.services.time",
                                     :message_id  => Kernel.rand(10101010).to_s,
                                     :reply_to    => replies_queue.name)
  end


  Signal.trap("INT") { connection.close { EventMachine.stop } }
end
```

#### Server code

``` ruby
require "amqp"

EventMachine.run do
  connection = AMQP.connect
  channel    = AMQP::Channel.new(connection)

  requests_queue = channel.queue("amqpgem.examples.services.time", :exclusive => true, :auto_delete => true)
  requests_queue.subscribe(:ack => true) do |metadata, payload|
    puts "[requests] Got a request #{metadata.message_id}. Sending a reply..."
    channel.default_exchange.publish(Time.now.to_s,
                                     :routing_key    => metadata.reply_to,
                                     :correlation_id => metadata.message_id,
                                     :mandatory      => true)

    metadata.ack
  end


  Signal.trap("INT") { connection.close { EventMachine.stop } }
end
```


### Related patterns

Request/Reply demonstrates two common techniques that are sometimes
referred to as messaging patterns of its own:

  * [Correlation Identifier](http://www.eaipatterns.com/CorrelationIdentifier.html) (for identifying what request incoming response is for)
  * [Return Address](http://www.eaipatterns.com/ReturnAddress.html) (for identifying where replies should be sent)

Other related patterns are
  * Scatter/Gather
  * Smart Proxy

## Command pattern

### Description and Use cases

The Command pattern is very similar to Request/Reply, except that there is no reply and messages are typed. For example, most modern Web applications have at least one "background task processor" that carries out a number of operations asynchronously, without sending any responses back. The Command pattern usually assumes 1:1 communication.

Some specific examples of the Command pattern are:

 * Account termination in a Web app triggers information archiving (or deletion) that is done by a separate app "in the background".
 * After a document or profile update, a Web app sends out commands to a search indexer application.
 * Virtual machines control dashboard app sends virtual machine controller application a command to reboot.

### RabbitMQ-based implementation

Implementation of the Command pattern on top of AMQP 0.9.1 involves well-known durable queues. The application that issues the command then can use the default exchange to publish messages to well-known services directly. The Request message :type attribute then indicates the command type and the message body (or body and headers) carry any additional information that the consumer needs to carry out the command.

#### Request message attributes

<dl>
  <dt>:type</dt>
  <dd>Message type as a string. For example: gems.install or commands.shutdown</dd>
</dl>

### Code example

#### Consumer (Recipient)

``` ruby
require "rubygems"
require "amqp"
require "yaml"

t = Thread.new { EventMachine.run }
sleep(0.5)


connection = AMQP.connect
channel    = AMQP::Channel.new(connection, :auto_recovery => true)

channel.prefetch(1)

# Acknowledgements are good for letting the server know
# that the task is finished. If the consumer doesn't send
# the acknowledgement, then the task is considered to be unfinished
# and will be requeued when consumer closes AMQP connection (because of a crash, for example).
channel.queue("amqpgem.examples.patterns.command", :durable => true, :auto_delete => false).subscribe(:ack => true) do |metadata, payload|
  case metadata.type
  when "gems.install"
    data = YAML.load(payload)
    puts "[gems.install] Received a 'gems.install' request with #{data.inspect}"

    # just to demonstrate a realistic example
    shellout = "gem install #{data[:gem]} --version '#{data[:version]}'"
    puts "[gems.install] Executing #{shellout}"; system(shellout)
    puts "[gems.install] Done"
    puts
  else
    puts "[commands] Unknown command: #{metadata.type}"
  end

  # message is processed, acknowledge it so that broker discards it
  metadata.ack
end

puts "[boot] Ready. Will be publishing commands every 10 seconds."
Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join
```

#### Producer (Sender)

``` ruby
require "amqp"
require "yaml"

t = Thread.new { EventMachine.run }
sleep(0.5)

connection = AMQP.connect
channel    = AMQP::Channel.new(connection)

# publish new commands every 3 seconds
EventMachine.add_periodic_timer(10.0) do
  puts "Publishing a command (gems.install)"
  payload = { :gem => "rack", :version => "~> 1.3.0" }.to_yaml

  channel.default_exchange.publish(payload,
                                   :type        => "gems.install",
                                   :routing_key => "amqpgem.examples.patterns.command")
end

puts "[boot] Ready"
Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join
```

### Related patterns

 * Event
 * Request/Reply

## Event pattern

### Description and Use cases

The Event pattern is a version of the Command pattern, but with one or more receivers (1:N communication). The world we live in is full of events, so applications of this pattern are endless.

Some specific use cases of the Event pattern are

  * Event logging (one application asks an event collector to record certain events and possibly take action)
  * Event propagation in MMO games
  * Live sport score updates
  * Various "push notifications" for mobile applications

The Event pattern is very similar to the Command pattern, however, there are typically certain differences between the two:

  * Event listeners often do not respond to event producers
  * Event listeners are often concerned with data collection: they update counters, persist event information and so on
  * There may be more than one event listener in the system. Commands are often carried out by one particular application

### RabbitMQ-based implementation

Because the Event pattern is a 1:N communication pattern, it typically uses a fanout exchange. Event listeners then use server-named exclusive queues all bound to that exchange. Event messages use the :type message attribute to indicate the event type and the message body (plus, possibly, message headers) to pass event context information.

#### Request message attributes

<dl>
  <dt>:type</dt>
  <dd>Message type as a string. For example: files.created, files.indexed or pages.viewed</dd>
</dl>
<span class="note">Due to misconfiguration or different upgrade time/policy, applications may receive events that they do not know how to handle. It is important for developers to handle such cases, otherwise it is likely that consumers will crash.</span>

More on fanout exchange type in the [Working With Exchanges](/articles/working_with_exchanges/) guide.

### Code example

#### Producer (Sender)

``` ruby
# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"
require "yaml"

t = Thread.new { EventMachine.run }
sleep(0.5)

connection = AMQP.connect
channel    = AMQP::Channel.new(connection)
exchange   = channel.fanout("amqpgem.patterns.events", :durable => true, :auto_delete => false)


EVENTS     = {
  "pages.show" => {
    :url      => "https://mysite.local/widgets/81772",
    :referrer => "http://www.google.com/search?client=safari&rls=en&q=widgets&ie=UTF-8&oe=UTF-8"
  },
  "widgets.created" => {
    :id       => 10,
    :shape    => "round",
    :owner_id => 1000
  },
  "widgets.destroyed" => {
    :id        => 10,
    :person_id => 1000
  },
  "files.created" => {
    :sha1      => "1a62429f47bc8b405d17e84b648f2fbebc555ee5",
    :filename  => "document.pdf"
  },
  "files.indexed" => {
    :sha1      => "1a62429f47bc8b405d17e84b648f2fbebc555ee5",
    :filename  => "document.pdf",
    :runtime   => 1.7623,
    :shared    => "shard02"
  }
}

def generate_event
  n       = (EVENTS.size * Kernel.rand).floor
  type    = EVENTS.keys[n]
  payload = EVENTS[type]

  [type, payload]
end

# broadcast events
EventMachine.add_periodic_timer(2.0) do
  event_type, payload = generate_event

  puts "Publishing a new event of type #{event_type}"
  exchange.publish(payload.to_yaml, :type => event_type)
end

puts "[boot] Ready. Will be publishing events every few seconds."
Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join
```

#### Consumer (Handler)

``` ruby
# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"
require "yaml"

t = Thread.new { EventMachine.run }
sleep(0.5)


connection = AMQP.connect
channel    = AMQP::Channel.new(connection, :auto_recovery => true)
channel.on_error do |ch, channel_close|
  raise "Channel-level exception: #{channel_close.reply_text}"
end

channel.prefetch(1)

channel.queue("", :durable => false, :auto_delete => true).bind("amqpgem.patterns.events").subscribe do |metadata, payload|
  begin
    body = YAML.load(payload)

    case metadata.type
    when "widgets.created"   then
      puts "A widget #{body[:id]} was created"
    when "widgets.destroyed" then
      puts "A widget #{body[:id]} was destroyed"
    when "files.created"     then
      puts "A new file (#{body[:filename]}, #{body[:sha1]}) was uploaded"
    when "files.indexed"     then
      puts "A new file (#{body[:filename]}, #{body[:sha1]}) was indexed"
    else
      puts "[warn] Do not know how to handle event of type #{metadata.type}"
    end
  rescue Exception => e
    puts "[error] Could not handle event of type #{metadata.type}: #{e.inspect}"
  end
end

puts "[boot] Ready"
Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join
```

### Related patterns

 * Command
 * Publish/Subscribe

## Document Message pattern

### Description and Use cases

The Document Message pattern is very similar to the Command and Event
patterns. The difference is in the intent. A Command message tells the
receiver to invoke certain behavior, whereas a Document Message just
passes data and lets the receiver decide what to do with the data.

The message payload is a single logical entity, for example, one (or a
group of closely related) database rows or documents.

Use cases for the Document Message pattern often have something to do
with processing of documents:

 * Indexing
 * Archiving
 * Content extraction
 * Transformation (translation, transcoding and so on) of document data

## Competing Consumers pattern

### Description and Use cases

[Competing
Consumers](http://www.eaipatterns.com/CompetingConsumers.html) are
multiple consumers that process messages from a shared queue.

TBD

### RabbitMQ-based implementation

TBD

### Code example

TBD

## Publish/Subscribe pattern

### Description and Use cases

TBD

### RabbitMQ-based implementation

TBD

### Code example

TBD

## Scatter/Gather pattern

### Description and Use cases

TBD

### RabbitMQ-based implementation

TBD

### Code example

TBD

## Smart Proxy pattern

### Description and Use cases

TBD

### RabbitMQ-based implementation

TBD

### Code example

TBD

## Multistep Processing (Routing Slip) pattern

### Description and Use cases

TBD

### RabbitMQ-based implementation

TBD

### Code example

TBD
