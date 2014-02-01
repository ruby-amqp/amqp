## Changes Between 1.2.x and 1.3.0

### Exchange-to-Exchange Bindings Support

amqp gem now supports [Exchange-to-Exchange Bindings](http://www.rabbitmq.com/e2e.html), a RabbitMQ
extension.

`AMQP::Exchange#bind` and `AMQP::Exchange#unbind` work very much like `AMQP::Queue#bind` and
`AMQP::Queue#unbind`, with the argument exchange being the source one.

Contributed by Stefan Kaes.

### Internal Exchange Declaration

amqp gem now supports declaration of internal exchanges
(used via exchange-to-exchange bindings, cannot be published to
by clients).

To declare an exchange as internal, add `:internal => true` to
declaration options.

Contributed by Stefan Kaes.


### Initial Connection Failures Retries

Set connection status to closed on connection failure, which
means connection retries succeed.

Contributed by Marius Hanne.

## Changes Between 1.1.0 and 1.2.0

### [Authentication Failure Notification](http://www.rabbitmq.com/auth-notification.html) Support

amqp gem now supports [Authentication Failure
Notification](http://www.rabbitmq.com/auth-notification.html). Public
API for authentication failure handling hasn't changed.

This extension is available in RabbitMQ 3.2+.

## basic.qos Recovery Fix

`basic.qos` setting will now be recovered first thing after
channel recovery, to the most recent value passed via `:prefetch` channel
constructor option or `AMQP::Channel#prefetch`.


### amq-protocol Update

Minimum `amq-protocol` version is now `1.9.2`.

### Automatic Recovery Fix

Automatic connection recovery now correctly recovers bindings again.

Contributed by Devin Christensen.


### 65535 Channels Per Connection

amqp gem now allows for	65535 channels per connection and
not Ruby process.

Contributed by Neo (http://neo.com) developers.

### channel.close is Delayed Until After Channel is Open

This eliminates a race condition in some codebases that use
very short lived channels.

### ConnectionClosedError is Back

`ConnectionClosedError` from `amq-client` is now defined again.


### Fixed Exceptions in AMQP::Exchange#handle_declare_ok

`AMQP::Exchange#handle_declare_ok` no longer raises an exception
about undefined methods `#anonymous?` and `#exchange`.


## Changes Between 1.0.0 and 1.1.0

### amq-protocol Update

Minimum `amq-protocol` version is now `1.8.0` which includes
a bug fix for messages exactly 128 Kb in size.


### AMQ::Client is Removed

`amq-client` has been incorporated into amqp gem. `AMQ::Client` and related
modules are no longer available.

### AMQP::Channel#confirm_select is Now Delayed

`AMQP::Channel#confirm_select` is now delayed until after the channel
is opened, making it possible to use it with the pseudo-synchronous
code style.

### RabbitMQ Extensions are Now in Core

amqp gem has been targeting RabbitMQ exclusively for a while now.

RabbitMQ extensions are now loaded by default and will be even more
tightly integrated in the future.

### AMQP::Channel.default is Removed

`AMQP::Channel.default` and method_missing-based operations on the default
channel has been removed. They've been deprecated since 0.6.

### AMQP::Channel#rpc is Removed

`AMQP::RPC`-related code has been removed. It has been deprecated
since 0.7.

### AMQP::Channel.on_error is Removed

Long time deprecated `AMQP::Channel.on_error` is removed.


## Version 1.0.0

### Deprecated APIs are Being Removed

Most of public API bits deprecated in 0.8.0 are COMPLETELY REMOVED.
