#!/bin/sh

${RABBITMQCTL:="$RABBITMQCTL"}
${RABBITMQ_PLUGINS:="sudo rabbitmq-plugins"}

# guest:guest has full access to /

$RABBITMQCTL add_vhost /
$RABBITMQCTL add_user guest guest
$RABBITMQCTL set_permissions -p / guest ".*" ".*" ".*"


# amqp_gem:amqp_gem_password has full access to amqp_gem_testbed

$RABBITMQCTL add_vhost amqp_gem_testbed
$RABBITMQCTL add_user amqp_gem amqp_gem_password
$RABBITMQCTL set_permissions -p amqp_gem_testbed amqp_gem ".*" ".*" ".*"


# amqp_gem_reader:reader_password has read access to amqp_gem_testbed

$RABBITMQCTL add_user amqp_gem_reader reader_password
$RABBITMQCTL clear_permissions -p amqp_gem_testbed guest
$RABBITMQCTL set_permissions -p amqp_gem_testbed amqp_gem_reader "^---$" "^---$" ".*"

# requires RabbitMQ 3.0+
# $RABBITMQ_PLUGINS enable rabbitmq_consistent_hash_exchange
