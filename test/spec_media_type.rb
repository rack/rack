# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/media_type'
end

describe Rack::MediaType do
  before { @empty_hash = {} }

  describe 'when content_type nil' do
    before { @content_type = nil }

    it '#type is nil' do
      Rack::MediaType.type(@content_type).must_be_nil
    end

    it '#params is empty' do
      Rack::MediaType.params(@content_type).must_equal @empty_hash
    end
  end

  describe 'when content_type is empty string' do
    before { @content_type = '' }

    it '#type is nil' do
      Rack::MediaType.type(@content_type).must_be_nil
    end

    it '#params is empty' do
      Rack::MediaType.params(@content_type).must_equal @empty_hash
    end
  end

  describe 'when content_type contains only media_type' do
    before { @content_type = 'application/text' }

    it '#type is application/text' do
      Rack::MediaType.type(@content_type).must_equal 'application/text'
    end

    it '#params is empty' do
      Rack::MediaType.params(@content_type).must_equal @empty_hash
    end
  end

  describe 'when content_type contains media_type and params' do
    before { @content_type = 'application/text;CHARSET="utf-8"' }

    it '#type is application/text' do
      Rack::MediaType.type(@content_type).must_equal 'application/text'
    end

    it '#params has key "charset" with value "utf-8"' do
      Rack::MediaType.params(@content_type)['charset'].must_equal 'utf-8'
    end
  end

  describe 'when content_type contains media_type and incomplete params' do 
    before { @content_type = 'application/text;CHARSET' }

    it '#type is application/text' do
      Rack::MediaType.type(@content_type).must_equal 'application/text'
    end

    it '#params has key "charset" with value ""' do
      Rack::MediaType.params(@content_type)['charset'].must_equal ''
    end
  end

  describe 'when content_type contains media_type and empty params' do 
    before { @content_type = 'application/text;CHARSET=' }

    it '#type is application/text' do
      Rack::MediaType.type(@content_type).must_equal 'application/text'
    end

    it '#params has key "charset" with value of empty string' do
      Rack::MediaType.params(@content_type)['charset'].must_equal ''
    end
  end

  {
    'application/text;;charset=utf-8'   => { 'charset' => 'utf-8' },
    'application/text; ;charset=utf-8'  => { 'charset' => 'utf-8' },
    'application/text,,charset=utf-8'   => { 'charset' => 'utf-8' },
    'application/text;;'                => {},
    'application/text;;;'               => {},
    'application/text;charset=utf-8;;'  => { 'charset' => 'utf-8' },
    'application/text;;charset'         => { 'charset' => '' },
    'application/text;;charset='        => { 'charset' => '' },
    'application/text;=utf-8'           => { '' => 'utf-8' },
  }.each do |content_type, expected|
    describe "when content_type is #{content_type.inspect}" do
      it "#params is #{expected.inspect}" do
        Rack::MediaType.params(content_type).must_equal expected
      end

      it '#type is application/text' do
        Rack::MediaType.type(content_type).must_equal 'application/text'
      end
    end
  end
end
