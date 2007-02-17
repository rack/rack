require 'yaml'
require 'net/http'

class TestRequest
  TEST_ENV = {
    "REQUEST_METHOD" => "GET",
    "SERVER_NAME" => "example.org",
    "SERVER_PORT" => "8080",
    "QUERY_STRING" => "",
    "rack.version" => [0,1],
    "rack.input" => StringIO.new,
    "rack.errors" => StringIO.new,
    "rack.multithread" => true,
    "rack.multiprocess" => true,
    "rack.run_once" => false,
    "rack.url_scheme" => "http",
    "PATH_INFO" => "/",
  }

  def self.env(modifier)
    e = TEST_ENV.dup
    e.update modifier
    e.delete_if { |k, v| v.nil? }
    e
  end


  def call(env)
    status = env["QUERY_STRING"] =~ /secret/ ? 403 : 200
    env["test.postdata"] = env["rack.input"].read
    [status, {"Content-Type" => "text/yaml"}, [env.to_yaml]]
  end

  module Helpers
    attr_reader :status, :response

    def GET(path, header={})
      Net::HTTP.start(@host, @port) { |http|
        user = header.delete(:user)
        passwd = header.delete(:passwd)

        get = Net::HTTP::Get.new(path, header)
        get.basic_auth user, passwd  if user && passwd
        http.request(get) { |response|
          @status = response.code.to_i
          @response = YAML.load(response.body)
        }
      }
    end

    def POST(path, formdata={}, header={})
      Net::HTTP.start(@host, @port) { |http|
        user = header.delete(:user)
        passwd = header.delete(:passwd)

        post = Net::HTTP::Post.new(path, header)
        post.form_data = formdata
        post.basic_auth user, passwd  if user && passwd
        http.request(post) { |response|
          @status = response.code.to_i
          @response = YAML.load(response.body)
        }
      }
    end
  end
end
