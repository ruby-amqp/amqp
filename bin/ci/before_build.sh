#!/bin/sh

# guest:guest has full access to /

sudo rabbitmqctl add_vhost /
sudo rabbitmqctl add_user guest guest
sudo rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"


# amqp_gem:amqp_gem_password has full access to amqp_gem_testbed

sudo rabbitmqctl add_vhost amqp_gem_testbed
sudo rabbitmqctl add_user amqp_gem amqp_gem_password
sudo rabbitmqctl set_permissions -p amqp_gem_testbed amqp_gem ".*" ".*" ".*"


# amqp_gem_reader:reader_password has read access to amqp_gem_testbed

sudo rabbitmqctl add_user amqp_gem_reader reader_password
sudo rabbitmqctl clear_permissions -p amqp_gem_testbed guest
sudo rabbitmqctl set_permissions -p amqp_gem_testbed amqp_gem_reader "^---$" "^---$" ".*"