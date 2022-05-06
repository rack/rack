# frozen_string_literal: true

if ENV.delete('COVERAGE')
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    add_filter "/test/"
    add_filter "/lib/rack/handler"
    add_group('Missing'){|src| src.covered_percent < 100}
    add_group('Covered'){|src| src.covered_percent == 100}
  end
end

$:.unshift(File.expand_path('../lib', __dir__))
if ENV['SEPARATE']
  def self.separate_testing
    yield
  end
else
  require_relative '../lib/rack'

  def self.separate_testing
  end
end

require 'minitest/global_expectations/autorun'
require 'stringio'

class Minitest::Spec
  def self.deprecated(*args, &block)
    it(*args) do
      begin
        verbose, $VERBOSE = $VERBOSE, nil
        instance_exec(&block)
      ensure
        $VERBOSE = verbose
      end
    end
  end
end
