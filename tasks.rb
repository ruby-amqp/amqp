#!/usr/bin/env nake
# encoding: utf-8

if RUBY_VERSION =~ /^1.9/
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end


require "contributors"
load "contributors.nake"
