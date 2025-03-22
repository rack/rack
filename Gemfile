# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :maintenance, optional: true do
  gem "rubocop", require: false
  gem "rubocop-packaging", require: false
end

group :doc do
  # gem "rdoc", git: "https://github.com/rdoc/rdoc.git"
  gem "rdoc", git: "https://github.com/Shopify/rdoc.git", branch: "fix-#1107"
end

group :test do
  gem "logger"
  gem "webrick"

  unless ENV['CI'] == 'spec'
    gem 'bake-test-external'
  end
end
