# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :maintenance, optional: true do
  gem "rubocop", require: false
  gem "rubocop-packaging", require: false
end

group :doc do
  gem "rdoc"
  gem "psych", "< 5" if RUBY_VERSION[0..2] == "2.5"
end

group :test do
  gem "logger"
  gem "webrick"

  unless ENV['CI'] == 'spec'
    gem 'bake-test-external'
  end
end
