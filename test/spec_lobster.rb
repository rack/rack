# frozen_string_literal: true

require_relative 'helper'
require 'rack/lobster'

module LobsterHelpers
  def lobster
    Rack::MockRequest.new Rack::Lint.new(Rack::Lobster.new)
  end

  def lambda_lobster
    Rack::MockRequest.new Rack::Lint.new(Rack::Lobster::LambdaLobster)
  end
end

describe Rack::Lobster::LambdaLobster do
  include LobsterHelpers

  it "be a single lambda" do
    Rack::Lobster::LambdaLobster.must_be_kind_of Proc
  end

  it "look like a lobster" do
    res = lambda_lobster.get("/")
    res.must_be :ok?
    res.join.must_include "(,(,,(,,,("
    res.join.must_include "?flip"
  end

  it "be flippable" do
    res = lambda_lobster.get("/?flip")
    res.must_be :ok?
    res.join.must_include "(,,,(,,(,("
  end
end

describe Rack::Lobster do
  include LobsterHelpers

  it "look like a lobster" do
    res = lobster.get("/")
    res.must_be :ok?
    res.join.must_include "(,(,,(,,,("
    res.join.must_include "?flip"
    res.join.must_include "crash"
  end

  it "be flippable" do
    res = lobster.get("/?flip=left")
    res.must_be :ok?
    res.join.must_include "),,,),,),)"
  end

  it "provide crashing for testing purposes" do
    lambda {
      lobster.get("/?flip=crash")
    }.must_raise RuntimeError
  end
end
