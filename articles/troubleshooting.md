---
title: "Troubleshooting RabbitMQ applications"
layout: article
disqus_identifier: "troubleshooting"
disqus_url: "http://rdoc.info/github/ruby-amqp/amqp/master/file/docs/Troubleshooting.textile"
---

## About this guide

This guide describes tools and strategies that help in troubleshooting
and debugging applications that use RabbitMQ in general and the [Ruby amqp
gem](http://github.com/ruby-amqp/amqp) in particular.

## Covered versions

This guide covers Ruby amqp gem 1.7.0 and later versions.

## First steps

Whenever something doesn’t work, check the following things before
asking on the mailing list:

 * RabbitMQ log.
 * List of users in a particular vhost you are trying to connect
 * Network connectivity. We know, it’s obvious, yet even experienced
developers and devops engineers struggle with network access
misconfigurations every once in a while.
 * If EventMachine is started in a separate thread, make sure that it
isn’t dead. If it is, this usually means that there was an exception
that caused it to terminate, or the environment uses the fork(2) system
call.

## Inspecting RabbitMQ log file

In this section we will cover typical problems that can be tracked down
by reading the RabbitMQ log.

RabbitMQ logs abrupt TCP connection failures, timeouts, protocol version
mismatches and so on. If you are running RabbitMQ, log locations for
various operating systems and distributions are documented in the
[RabbitMQ installation guide](http://www.rabbitmq.com/install.html)

On Mac OS X, RabbitMQ installed via Homebrew logs to
\$HOMEBREW_HOME/var/log/rabbitmq/rabbit@\$HOSTNAME.log. For example, if
you have Homebrew installed at /usr/local and your hostname is giove,
the log will be at /usr/local/var/log/rabbitmq/rabbit@giove.log.

Here is what authentication failure looks like in a RabbitMQ log:

```
=ERROR REPORT 17-May-2011::17:37:58 =
exception on TCP connection <0.4770.0> from 127.0.0.1:46551
{channel0_error,starting,
                {amqp_error,access_refused,
                            "AMQPLAIN login refused: user 'pipeline_agent' - invalid credentials",
                            'connection.start_ok'}}
```

This means that the connection attempt with username pipeline_agent failed because the credentials were invalid. If you are seeing this message, make sure username, password *and vhost* are correct.

The following entry:

```
=ERROR REPORT 17-May-2011::17:26:28 =
exception on TCP connection <0.4201.62> from 10.8.0.30:57990
{bad_header,<<65,77,81,80,0,0,9,1>>}
```

means that the client supports AMQP 0.9.1 but the broker doesn’t
(RabbitMQ versions pre-2.0 only support AMQP 0.8, for example). If you
are using amqp gem 0.8 or later and seeing this entry in your broker
log, you are connecting to an RabbitMQ that is too old to support
this amqp gem version. In the case of RabbitMQ, make sure that you run
version 2.0 or later.


## Handling channel-level exceptions

A broad range of problems result in AMQP channel exceptions: an
indication by the broker that there was an issue that the application
needs to be aware of. Channel-level exceptions are typically not fatal
and can be recovered from. Some examples are:

* Exchange is re-declared with attributes different from the original
declaration. For example, a non-durable exchange is being re-declared as
durable.
 * Queue is re-declared with attributes different from the original
declaration. For example, an auto-deletable queue is being re-declared
as non-auto-deletable.
 * Queue is bound to an exchange that does not exist.

and so on. When troubleshooting RabbitMQ applications, it is recommended
that you detect and handle channel-level exceptions on all of the
channels that your application may use. For that, use the
`AMQP::Channel#on_error` method as demonstrated below:

``` ruby
events_channel.on_error do |ch, channel_close|
  puts "Channel-level exception on the events channel: #{channel_close.reply_text}"
end

commands_channel.on_error do |ch, channel_close|
  puts "Channel-level exception on the commands channel: #{channel_close.reply_text}"
end
```

Defining channel-level exception handlers will reveal many issues that
it might take more time to detect using other troubleshooting
techniques.

## Testing network connection with RabbitMQ using Telnet

One simple way to check network connection between a particular network
node and a node running an RabbitMQ is to use `telnet`:

```
telnet [host or ip] 5672
```

then enter any random string of text and hit Enter. The RabbitMQ
should close the connection when you enter anything other than
supported protocol handshake. Here is an example
session:

```
telnet localhost 5672
Connected to localhost.
Escape character is ‘^]’.
adjasd
AMQP Connection closed by foreign host.
```

If Telnet exits after printing instead

```
telnet: connect to address [host or ip]: Connection refused
telnet: Unable to connect to remote host
```

then the connection between the machine that you are running Telnet
tests on and the RabbitMQ fails. This can be due to many different
reasons, but it is a good idea to check these two things first:

 * Firewall configuration for port 5672
 * DNS setup (if hostname is used)


## RabbitMQ Startup Issues

### Missing erlang-os-mon on Debian and Ubuntu

The following error on RabbitMQ startup on Debian or Ubuntu

```
ERROR: failed to load application os_mon: {“no such file or
directory”,“os_mon.app”}
```

suggests that the **erlang-os-mon** package is not installed.
