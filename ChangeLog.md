## Changes Between 1.1.0 and 1.2.0

### channel.close is Delayed Until After Channel is Open

This eliminates a race condition in some codebases that use
very short lived channels.

### ConnectionClosedError is Back

`ConnectionClosedError` from `amq-client` is now defined again.


### amq-protocol Update

Minimum `amq-protocol` version is now `1.9.0`.

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
