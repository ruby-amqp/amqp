---
title: "amqp gem: Community and Getting Help"
layout: article
---

## Mailing List

[amqp gem has a mailing list](groups.google.com/group/ruby-amqp). We
encourage you to also join the
[rabbitmq-users](https://groups.google.com/forum/#!forum/rabbitmq-users)
mailing list. Feel free to ask any questions that you may have.


## IRC

For more immediate help, please join `#rabbitmq` on `irc.freenode.net`.


## News & Announcements on Twitter

To subscribe for announcements of releases, important changes and so on, please follow [@rubyamqp](https://twitter.com/#!/rubyamqp) on Twitter.


## Reporting Issues

If you find a bug, poor default, missing feature or find any part of
the API inconvenient, please [file an
issue](http://github.com/ruby-amqp/bunny/issues) on GitHub.  When
filing an issue, please specify which amqp gem and RabbitMQ versions you
are using, provide recent RabbitMQ log file contents if possible, and
try to explain what behavior you expected and why. Bonus points for
contributing failing test cases.


## Contributing

First, clone the repository and run

    bundle install --binstubs

and then run tests with

    CI=true ./bin/rspec -cfs spec

After that create a branch and make your changes on it. Once you are
done with your changes and all tests pass, submit a pull request on
GitHub.
