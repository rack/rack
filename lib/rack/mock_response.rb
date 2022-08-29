# frozen_string_literal: true

require 'cgi/cookie'
require 'time'

require_relative 'response'

module Rack
  # Rack::MockResponse provides useful helpers for testing your apps.
  # Usually, you don't create the MockResponse on your own, but use
  # MockRequest.

  class MockResponse < Rack::Response
    class << self
      alias [] new
    end

    # Headers
    attr_reader :original_headers, :cookies

    # Errors
    attr_accessor :errors

    def initialize(status, headers, body, errors = nil)
      @original_headers = headers

      if errors
        @errors = errors.string if errors.respond_to?(:string)
      else
        @errors = ""
      end

      super(body, status, headers)

      @cookies = parse_cookies_from_header
      buffered_body!
    end

    def =~(other)
      body =~ other
    end

    def match(other)
      body.match other
    end

    def body
      return @buffered_body if defined?(@buffered_body)

      # FIXME: apparently users of MockResponse expect the return value of
      # MockResponse#body to be a string.  However, the real response object
      # returns the body as a list.
      #
      # See spec_showstatus.rb:
      #
      #   should "not replace existing messages" do
      #     ...
      #     res.body.should == "foo!"
      #   end
      buffer = @buffered_body = String.new

      @body.each do |chunk|
        buffer << chunk
      end

      return buffer
    end

    def empty?
      [201, 204, 304].include? status
    end

    def cookie(name)
      cookies.fetch(name, nil)
    end

    private

    def parse_cookies_from_header
      cookies = Hash.new
      if headers.has_key? 'set-cookie'
        set_cookie_header = headers.fetch('set-cookie')
        Array(set_cookie_header).each do |header_value|
          header_value.split("\n").each do |cookie|
            cookie_name, cookie_filling = cookie.split('=', 2)
            cookie_attributes = identify_cookie_attributes cookie_filling
            parsed_cookie = CGI::Cookie.new(
              'name' => cookie_name.strip,
              'value' => cookie_attributes.fetch('value'),
              'path' => cookie_attributes.fetch('path', nil),
              'domain' => cookie_attributes.fetch('domain', nil),
              'expires' => cookie_attributes.fetch('expires', nil),
              'secure' => cookie_attributes.fetch('secure', false)
            )
            cookies.store(cookie_name, parsed_cookie)
          end
        end
      end
      cookies
    end

    def identify_cookie_attributes(cookie_filling)
      cookie_bits = cookie_filling.split(';')
      cookie_attributes = Hash.new
      cookie_attributes.store('value', cookie_bits[0].strip)
      cookie_bits.drop(1).each do |bit|
        if bit.include? '='
          cookie_attribute, attribute_value = bit.split('=', 2)
          cookie_attributes.store(cookie_attribute.strip.downcase, attribute_value.strip)
        end
        if bit.include? 'secure'
          cookie_attributes.store('secure', true)
        end
      end

      if cookie_attributes.key? 'max-age'
        cookie_attributes.store('expires', Time.now + cookie_attributes['max-age'].to_i)
      elsif cookie_attributes.key? 'expires'
        cookie_attributes.store('expires', Time.httpdate(cookie_attributes['expires']))
      end

      cookie_attributes
    end

  end
end
