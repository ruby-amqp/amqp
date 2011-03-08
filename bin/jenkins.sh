#!/bin/bash

echo -e "\n\n==== Setup ===="
git fetch && git reset origin/master --hard
./bin/set_test_suite_realms_up.sh

echo -e "\n\n==== Ruby 1.9.2 Head ===="
rvm use 1.9.2-head@ruby-amqp
bundle install --local; echo
bundle exec rspec spec
return_status=$?

echo -e "\n\n==== Ruby 1.8.7 ===="
rvm use 1.8.7@ruby-amqp
bundle install --local; echo
bundle exec rspec spec
return_status=$(expr $return_status + $?)

test $return_status -eq 0
