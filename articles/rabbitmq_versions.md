---
title: "Supported RabbitMQ Versions"
layout: article
---

## About this guide

This guide covers the compatibility of the [Ruby amqp
gem](http://github.com/ruby-amqp/amqp) with various versions of
[RabbitMQ](http://rabbitmq.com) messaging broker.

## Covered versions

This guide covers Ruby amqp gem 1.7.0 and later versions.

## RabbitMQ Version Requirement

amqp gem before 0.8.0 (0.6.x, 0.7.x) series implemented (most of) the
AMQP 0.8 specification. amqp gem 0.8.0 and later versions implement AMQP 0.9.1 and thus
**requires RabbitMQ version 2.0 or later**.

<span class="note">
amqp gem 0.8.0 and later versions implement AMQP 0.9.1 and thus
**require RabbitMQ version 2.0 or later**
</span>

## Using recent versions on Debian and Ubuntu

Ubuntu and Debian have both shipped with old RabbitMQ versions in the
past that only support AMQP protocol 0.8. Ruby amqp gem 0.8.0 and later
**will not work with RabbitMQ versions before 2.0.0**.

We strongly recommend that you use the [RabbitMQ apt
repository](http://www.rabbitmq.com/debian.html#apt) that has recent
versions of RabbitMQ.

## OpsCode Chef and Puppet

### Chef cookbook for RabbitMQ

There is a [Chef cookbook for
RabbitMQ](https://github.com/opscode-cookbooks/rabbitmq)
that installs recent versions from the rabbitmq.com apt repository. It
also has LWPRs (providers) for managing users and vhosts.

### RabbitMQ Puppet module

There is a [RabbitMQ Puppet
module](https://github.com/puppetlabs/puppetlabs-rabbitmq) by the Puppet
Labs team. It uses .deb packages from Debian testing and unstable
repositories. Note that it has two dependencies:

 * [puppet-stdlib](https://github.com/puppetlabs/puppetlabs-stdlib)
 * [puppet-apt](https://github.com/puppetlabs/puppet-apt)

## TLS (SSL) support

Note that [before 1.7.0, RabbitMQ did not support
TLS](http://www.rabbitmq.com/ssl.html). In order to have TLS support,
RabbitMQ 1.7.0 requires

 * Erlang/OTP R13B or later
 * Erlang SSL 3.10 or later

and recommends using Erlang R141B that ships with Erlang SSL 4.0.1.
Learn more in our [Using TLS
(SSL)](/article/connection_encryption_with_tls/) guide.
