# encoding: utf-8

$stdout.puts <<-MESSAGE
-------------------------------------------------------------------------------------
DEPRECATION WARNING!

Use of mq.rb is deprecated. Instead of

  require "mq"

please use

  require "amqp"


mq.rb will be REMOVED in AMQP gem version 1.0.

Why is it deprecated? Because it was a poor name choice all along. We better not
release 1.0 with it. Both mq.rb and MQ class step away from AMQP terminology and
make 8 out of 10 engineers think it has something to do with AMQP queues (in fact,
MQ should have been called Channel all along). No other AMQP client library we know
of invents its own terminology when it comes to AMQP entities, and amqp gem shouldn't,
too.

Learn more at http://bit.ly/amqp-gem-080-migration, all documentation guides are at
http://bit.ly/amqp-gem-docs, AMQP Model Explained at http://bit.ly/amqp-model-explained.

We are also in #rabbitmq on irc.freenode.net.

Thank you for understanding. AMQP gem maintainers team.

-------------------------------------------------------------------------------------
MESSAGE

require "amqp"
