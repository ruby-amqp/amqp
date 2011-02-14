#!/bin/sh

# Server-specific, I have RVM setup at the profile file:
source /etc/profile

rvm 1.9.2-head,1.8.7 exec bundle install && rspec spec
