#!/bin/sh

rvm 1.8.7-p174@amqp_gem
echo "\n\n\nNow running on 1.8.7-p174\n\n\n"

rspec spec
# to let broker chew through all the messages
# it may still be processing
sleep 2



rvm 1.9.1-p378@amqp_gem
echo "\n\n\nNow running on 1.9.1-p378\n\n\n"

rspec spec
sleep 2


rvm 1.9.2-p136@amqp_gem
echo "\n\n\nNow running on 1.9.2-p136\n\n\n"

rspec spec
sleep 2


rvm rbx-head@amqp_gem
echo "\n\n\nNow running on Rubinius HEAD\n\n\n"

rspec spec