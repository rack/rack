require 'rack'
require 'rack/options'

module Rack
  module Handler
    class WithoutOptions
      # has no method #valid_options for tests purpose
    end
    register :without_options, WithoutOptions
  end
end

module Rack
  module Handler
    class WithOptions
      def self.valid_options
        {
          "Opt1" => "option1 desc",
          "Opt2" => "option2 desc",
          "Opt3" => "option3 desc",
          "Host=HOST" => "Hostname to listen on (default: localhost)",
          "Port=PORT" => "Port to listen on (default: 8080)",
        }
      end
    end
    register :with_options, WithOptions
  end
end

describe Rack::Options do

  describe '#handler_opts' do
    should "return empty string when handler is without options" do
      Rack::Options.new.handler_opts({:server => 'without_options'}).should.equal ''
    end

    should "return text with handler options when handler is with options" do
      result = Rack::Options.new.handler_opts({:server => 'with_options'})
      result.should.not.equal ''
      result.should.match(/Opt1/)
      result.should.match(/Opt2/)
      result.should.match(/Opt3/)
    end

    should "ignore Host and Port options of handler" do
      result = Rack::Options.new.handler_opts({:server => 'with_options'})
      result.should.not.equal ''
      result.should.not.match(/Host/)
      result.should.not.match(/Port/)
    end

    # it shouldn't be acting this way:
    it "raises LoadError, for now, but it is wrong; when handler was not found" do
      lambda {
        Rack::Options.new.handler_opts({:server => 'non_exsisting'})
      }.should.raise LoadError
    end

    # it should be acting this way:
    # should "return Warning-text when handler was not found" do
    #   result = Rack::Options.new.handler_opts({:server => 'non_exsisting'})
    #   result.should.not.equal ''
    #   result.should.match(/Warning/)
    # end
  end

end
