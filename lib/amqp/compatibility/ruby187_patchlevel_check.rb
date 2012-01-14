# encoding: utf-8

if RUBY_VERSION =~ /^1.8.7/
  require "rbconfig"
  conf = RbConfig::CONFIG

  # looks like PATCHLEVEL was added after 1.8.7-p249 release :( MK.
  if (conf["PATCHLEVEL"] && conf["PATCHLEVEL"] == "249") || (conf["libdir"] =~ /1.8.7-p249/)
    raise <<-MESSAGE
IMPORTANT: amqp gem 0.8.0+ does not support Ruby 1.8.7-p249 (this exact patch level. p174, p334 and later patch levels are supported!)
because of a nasty Ruby bug (http://bit.ly/iONBmH). Refer to http://groups.google.com/group/ruby-amqp/browse_thread/thread/37d6dcc1aea1c102
for more information, especially if you want to verify whether a particular Ruby patch level or version or build suffers from
this issue.

To reiterate: 1.8.7-p174, p334 and later patch levels are supported, see http://travis-ci.org/ruby-amqp/amqp. The fix was committed to MRI in December 2009. It's
a good idea to upgrade, although downgrading to p174 is an option, too.

To learn more (including the 0.8.x migration guide) at http://bit.ly/rubyamqp and https://github.com/ruby-amqp.
    MESSAGE
  end
end
