# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # gem "rack", "~> 3.0.0"
  # gem "rack", "~> 3.1.0"
	gem "rack", path: "."
end

require "action_controller/railtie"

class TestApp < Rails::Application
  config.root = __dir__
  config.hosts << "www.example.com"
  config.secret_key_base = "secret_key_base"
  config.action_dispatch.show_exceptions = :rescuable
  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger

  routes.draw do
    get "/head" => "test#one"
    get "/empty" => "test#two"
    get "/body" => "test#three"
  end
end

class TestController < ActionController::Base
  def one
    head 200
  end
  def two
    render plain: ''
  end
  def three
    render plain: 'a', layout: false
  end
end

require "minitest/autorun"

class TestControllerTest < ActionDispatch::IntegrationTest

  # works on rack 3.0
  # content-length key is missing on rack 3.1
  def test_head
    get "/head"
    assert_response 200
    assert_equal '0', headers['content-length']
    # assert headers.key?('content-length')
  end

  # works on rack 3.0
  # content-length key is missing on rack 3.1
  def test_empty_body
    get "/empty"
    assert_response 200
    assert_equal '0', headers['content-length']
    # assert headers.key?('content-length')
  end

  # works on rack 3.0 and 3.1
  def test_with_body
    get "/body"
    assert_response 200
    assert_equal '1', headers['content-length']
  end

  private
    def app
      Rails.application
    end
end
