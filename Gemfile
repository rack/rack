source 'https://rubygems.org'

gemspec

# Rake 11+ is Ruby 1.9+ only. Stick with 10.x to avoid awkward Bundler
# platform and RUBY_VERSION gymnastics, or separate Gemfiles.
gem "rake", "< 11.0"

# What we need to do here is just *exclude* JRuby, but bundler has no way to do
# this, because of some argument that I know I had with Yehuda and Carl years
# ago, but I've since forgotten. Anyway, we actually need it here, and it's not
# avaialable, so prepare yourself for a yak shave when this breaks.
c_platforms = Bundler::Dsl::VALID_PLATFORMS.dup.delete_if do |platform|
  # to_s because we still run 1.8
  platform.to_s =~ /jruby/
end

# Alternative solution that might work, but it has bad interactions with
# Gemfile.lock if that gets committed/reused:
# c_platforms = [:mri] if Gem.platforms.last.os == "java"

group :extra do
  gem 'fcgi', :platforms => c_platforms
  gem 'memcache-client'
  gem 'mongrel', '>= 1.2.0.pre2', :platforms => c_platforms
  gem 'thin', :platforms => c_platforms
end
