# frozen_string_literal: true

$:.unshift(File.expand_path('../lib', __dir__))
require_relative '../lib/rack'
require 'minitest/global_expectations/autorun'
require 'stringio'
