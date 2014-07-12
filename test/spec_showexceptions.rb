require 'rack/showexceptions'
require 'rack/lint'
require 'rack/mock'

describe Rack::ShowExceptions do
  def show_exceptions(app)
    Rack::Lint.new Rack::ShowExceptions.new(app)
  end
  
  it "catches exceptions" do
    res = nil

    req = Rack::MockRequest.new(
      show_exceptions(
        lambda{|env| raise RuntimeError }
    ))

    lambda{
      res = req.get("/", "HTTP_ACCEPT" => "text/html")
    }.should.not.raise

    res.should.be.a.server_error
    res.status.should.equal 500

    res.should =~ /RuntimeError/
    res.should =~ /ShowExceptions/
  end

  it "responds with HTML on AJAX requests accepting HTML" do
    res = nil

    req = Rack::MockRequest.new(
      show_exceptions(
        lambda{|env| raise RuntimeError, "It was never supposed to work" }
    ))

    lambda{
      res = req.get("/", "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest", "HTTP_ACCEPT" => "text/html")
    }.should.not.raise

    res.should.be.a.server_error
    res.status.should.equal 500

    res.content_type.should.equal "text/html"

    res.body.should.include "RuntimeError"
    res.body.should.include "It was never supposed to work"
    res.body.should.include Rack::Utils.escape_html(__FILE__)
  end

  it "handles exceptions without a backtrace" do
    res = nil

    req = Rack::MockRequest.new(
      show_exceptions(
        lambda{|env| raise RuntimeError, "", [] }
      )
    )

    lambda{
      res = req.get("/", "HTTP_ACCEPT" => "text/html")
    }.should.not.raise

    res.should.be.a.server_error
    res.status.should.equal 500

    res.should =~ /RuntimeError/
    res.should =~ /ShowExceptions/
    res.should =~ /unknown location/
  end

  def request
    Rack::MockRequest.new(
      show_exceptions(
        lambda{|env| raise RuntimeError, "Error from application" }
      )
    )
  end


  it "responds with plain text to ACCEPT HEADER */*" do
    response = request.get("/", "HTTP_ACCEPT" => "text/plain")

    response.content_type.should.equal "text/plain"
  end

  it "responds with html only when explicity preferred" do
    response = request.get("/", "HTTP_ACCEPT" => "text/plain;q=0.7,text/html;q=0.8")

    response.content_type.should.equal "text/html"
  end

  it "responds with plain text when there is no matching mime type" do
    response = request.get("/", "HTTP_ACCEPT" => "appication/json")

    response.content_type.should.equal "text/plain"
  end

  it "responds with HTML to a typical browser get document header" do
    response = request.get("/", "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8")

    response.content_type.should.equal "text/html"
  end
end
