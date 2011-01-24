#!/bin/sh

rvm use 1.8.7-p174@amqp_gem
ruby --version
echo "Now running on 1.8.7-p174\n\n\n"

bundle install
rspec spec
# to let broker chew through all the messages
# it may still be processing
sleep 2


rvm use 1.9.1-p378@amqp_gem
ruby --version
echo "Now running on 1.9.1-p378\n\n\n"

bundle install
rspec spec
sleep 2


rvm use 1.9.2-p136@amqp_gem
ruby --version
echo "Now running on 1.9.2-p136\n\n\n"

bundle install
rspec spec
sleep 2


rvm use rbx-head@amqp_gem
ruby --version
echo "Now running on Rubinius HEAD\n\n\n"

bundle install
rspec spec