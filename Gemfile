# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# What we need to do here is just *exclude* JRuby, but bundler has no way to do
# this, because of some argument that I know I had with Yehuda and Carl years
# ago, but I've since forgotten. Anyway, we actually need it here, and it's not
# avaialable, so prepare yourself for a yak shave when this breaks.
c_platforms = Bundler::Dsl::VALID_PLATFORMS.dup.delete_if do |platform|
  platform =~ /jruby/
end

gem "rubocop", require: false

# Alternative solution that might work, but it has bad interactions with
# Gemfile.lock if that gets committed/reused:
# c_platforms = [:mri] if Gem.platforms.last.os == "java"

group :extra do
  gem 'fcgi', platforms: c_platforms
  gem 'memcache-client'
  gem 'thin', platforms: c_platforms
end

group :doc do
  gem 'rdoc'
end
