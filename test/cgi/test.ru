#!/usr/bin/env ruby -I ../../lib ../../bin/rackup -E deployment -I ../../lib
# -*- ruby -*-

require '../testrequest'

run TestRequest.new
