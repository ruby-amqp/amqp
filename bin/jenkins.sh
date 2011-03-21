#!/bin/bash

echo -e "\n\n==== Setup ===="
source /etc/profile
git fetch && git reset origin/master --hard

# FIXME: Jenkins user doesn't have permissions to run it.
# PATH=/usr/sbin:$PATH ./bin/set_test_suite_realms_up.sh
echo "~ NOT running ./bin/set_test_suite_realms_up.sh"

echo -e "\n\n==== Ruby 1.9.2 Head ===="
rvm use 1.9.2-head@ruby-amqp
gem install bundler --no-ri --no-rdoc
bundle install --path vendor/bundle/1.9.2 --without development; echo
bundle exec rspec spec
return_status=$?

echo -e "\n\n==== Ruby 1.8.7 ===="
rvm use 1.8.7@ruby-amqp
gem install bundler --no-ri --no-rdoc
bundle install --path vendor/bundle/1.8.7 --without development; echo
bundle exec rspec spec
return_status=$(expr $return_status + $?)

test $return_status -eq 0
