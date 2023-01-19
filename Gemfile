# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem "webrick"

group :maintenance, optional: true do
  gem "rubocop", require: false
  gem "rubocop-packaging", require: false
end

group :doc do
  gem 'rdoc'
end

group :test do
  gem 'minitest'
  gem 'bake-test-external', '~> 0.1.3'
  if RUBY_VERSION >= '2.5' && RUBY_VERSION < '2.6'
    gem 'psych', '< 3'
  end
end
