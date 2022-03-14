---
title: "Using TLS (SSL) with Ruby amqp gem and RabbitMQ"
layout: article
---

## About this guide

This guide covers connection to RabbitMQ nodes using TLS (also known as
SSL) and related issues. This guide does not explain basic TLS concepts.
For that, refer to resources like [Introduction to
SSL](https://developer.mozilla.org/en/Introduction_to_SSL) or [Wikipedia
page on TLS](http://en.wikipedia.org/wiki/Transport_Layer_Security).

## Covered versions

This guide covers Ruby amqp gem 1.7.0 and later versions.

## RabbitMQ Version Requirements

RabbitMQ has supported TLS since version 1.7.0. Minimum requirements are

 * Erlang R13B
 * Erlang SSL application 3.10

The recommended distribution is R14B (SSL 4.0.1) or later. This should
be considered the minimum configuration for Java and Erlang clients due
to an incorrect RC4 implementation in earlier versions of Erlang.

Learn more at [rabbitmq.com TLS page](http://www.rabbitmq.com/ssl.html).

## Pre-requisites

RabbitMQ needs to be configured to use TLS. Just like Web
servers, TLS connections are usually accepted on a separate port (5671).
[rabbitmq.com TLS page](http://www.rabbitmq.com/ssl.html) describes how
to configure RabbitMQ to use TLS, how to generate certificates for
development and so on.

## Connecting to RabbitMQ using TLS

To instruct Ruby amqp gem to use TLS for connection, pass :ssl option
that specifies certificate chain file path as well as private key file
path:

``` ruby
AMQP.start(:port     => 5671,
           :ssl => {
             :cert_chain_file  => certificate_chain_file_path,
             :private_key_file => client_private_key_file_path
           }) do |connection|
  puts "Connected, authenticated. TLS seems to work."

  connection.disconnect { puts "Now closing the connection…"; EventMachine.stop }
end
 ```

Note that TLS connection may take a bit of time to establish (up to
several seconds in some cases). To verify that broker connection
actually uses TLS, refer to RabbitMQ log file:

```
=INFO REPORT==== 28-Jun-2011::08:41:24 ===
accepted TCP connection on 0.0.0.0:5671 from 127.0.0.1:53444

=INFO REPORT==== 28-Jun-2011::08:41:24 ===
starting TCP connection <0.9904.0> from 127.0.0.1:53444

=INFO REPORT==== 28-Jun-2011::08:41:24 ===
upgraded TCP connection <0.9904.0> to SSL
```

## Example code

TLS example (as well as sample certificates you can use to get started
with) can be found in the [amqp gem git
repository](https://github.com/ruby-amqp/amqp/tree/master/examples)
