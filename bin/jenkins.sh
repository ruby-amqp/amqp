#!/bin/bash

echo -e "\n\n==== Setup ===="
git fetch && git reset origin/master --hard
./bin/set_test_suite_realms_up.sh

echo -e "\n\n==== Ruby 1.9.2 Head ===="
rvm 1.9.2-head exec bundle install --local; echo
rvm 1.9.2-head exec bundle exec rspec spec
return_status=$?

echo -e "\n\n==== Ruby 1.8.7 ===="
rvm 1.8.7 exec bundle install --local; echo
rvm 1.8.7 exec bundle exec rspec spec
return_status=$(expr $return_status + $?)

test $return_status -eq 0
