#!/bin/sh

# guest:guest has full access to /amqp_gem_07x_stable_testbed

rabbitmqctl add_vhost /amqp_gem_07x_stable_testbed
rabbitmqctl add_user guest guest
rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"
