# amqp gem Documentation

[Ruby amqp gem](https://rubygems.org/gems/amqp) is the original EventMachine-based
Ruby client for [RabbitMQ](https://rabbitmq.com).



## Table of Contents
## [Getting Started with Ruby amqp gem and RabbitMQ](/articles/getting_started/)

An overview of amqp gem with a quick tutorial that helps you to get started with it. It should take about
20 minutes to read and study the provided code examples.


## [AMQP 0.9.1 Model Explained](/articles/amqp_9_1_model_explained.html)

This guide covers:

 * AMQP 0.9.1 model overview
 * What are channels
 * What are vhosts
 * What are queues
 * What are exchanges
 * What are bindings
 * What are AMQP 0.9.1 classes and methods


## [Connecting to RabbitMQ](/articles/connecting_to_broker.html)

This guide covers:

 * How to connect to RabbitMQ with amqp gem
 * How to use connection URI to connect to RabbitMQ (also: in PaaS environments such as Heroku and CloudFoundry)
 * How to open a channel
 * How to close a channel
 * How to disconnect

## [Working With Queues](/articles/working_with_queues.html)

This guide covers:

 * How to declare AMQP queues with amqp gem
 * Queue properties
 * How to declare server-named queues
 * How to declare temporary exclusive queues
 * How to consume messages ("push API")
 * How to fetch messages ("pull API")
 * Message and delivery properties
 * Message acknowledgements
 * How to purge queues
 * How to delete queues
 * Other topics related to queues

## [Working With Exchanges](/articles/working_with_exchanges.html)

This guide covers:

 * Exchange types
 * How to declare AMQP exchanges with amqp gem
 * How to publish messages
 * Exchange propreties
 * Fanout exchanges
 * Direct exchanges
 * Topic exchanges
 * Default exchange
 * Message and delivery properties
 * Message routing
 * Bindings
 * How to delete exchanges
 * Other topics related to exchanges and publishing


## [Working with bindings](/articles/bindings.html)

This guide covers:

 * How to bind exchanges to queues
 * How to unbind exchanges from queues
 * Other topics related to bindings


## [Durability and Related Matters](/articles/durability.html)

This guide covers:

 * Topics related to durability of exchanges and queues
 * Durability of messages


## [Patterns and Use Cases](/articles/patterns_and_use_cases.html)

This guide focuses implementation of common messaging patterns using
AMQP Model features as building blocks.


## [Error Handling and Recovery](/articles/error_handling.html)

This guide covers:

 * AMQP 0.9.1 protocol exceptions
 * How to deal with network failures
 * Other things that may go wrong


## [Using TLS (SSL) connections](/articles/connection_encryption_with_tls.html)

This guide covers:

 * How to use TLS (SSL) connections to RabbitMQ with amqp gem


## [RabbitMQ Extensions](/articles/rabbitmq_extensions.html)

This guide covers [RabbitMQ extensions](http://www.rabbitmq.com/extensions.html) and how they are used in amqp gem:

 * How to use Publishing Confirms with amqp gem
 * How to use exchange-to-exchange bindings
 * How to the alternate exchange extension
 * How to set per-queue message TTL
 * How to set per-message TTL
 * What are consumer cancellation notifications and how to use them
 * Message *dead lettering* and the dead letter exchange
 * How to use sender-selected routing (`CC` and `BCC` headers)


## [Troubleshooting your AMQP applications](/articles/troubleshooting.html)

Explains what to do when your AMQP applications using Ruby amqp gem
and RabbitMQ misbehave.


## [amqp gem 0.8 migration guide](/articles/08_migration.html)

Learn how to migrate your amqp gem 0.6.x and 0.7.x applications to
0.8.0 and later and why you should do it.


## [Testing AMQP applications with Evented Spec](/articles/testing_with_evented_spec.html)

Learn about techniques of asynchronous testing for your messaging
applications, and how to use Evented Spec.
