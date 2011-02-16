#!/bin/sh

# guest:guest has full access to /

rabbitmqctl add_vhost /
rabbitmqctl add_user guest guest
rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"


# amqp_gem:amqp_gem_password has full access to /amqp_gem_testbed

rabbitmqctl add_vhost /amqp_gem_testbed
rabbitmqctl add_user amqp_gem amqp_gem_password
rabbitmqctl set_permissions -p /amqp_gem_testbed amqp_gem ".*" ".*" ".*"


# amqp_gem_reader:reader_password has read access to /amqp_gem_testbed

rabbitmqctl add_user amqp_gem_reader reader_password
rabbitmqctl clear_permissions -p /amqp_gem_testbed guest
rabbitmqctl set_permissions -p /amqp_gem_testbed amqp_gem_reader "^---$" "^---$" ".*"