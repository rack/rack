# frozen_string_literal: true

require 'rack'

module Rack
  module Handler
    class Lambda
      def self.run(event:, context:)
        @app ||= Rack::Builder.parse_file("#{ENV['LAMBDA_TASK_ROOT']}/config.ru").first
        serve env(event, context)
      end

      def self.serve(env)
        status, headers, body = @app.call(env)

        {
          'statusCode' => status,
          'headers' => headers,
          'body' => body.map(&:to_s)
        }
      end

      def self.env(event, context)
        body = event['isBase64Encoded'] ? Base64.decode64(event['body']) : event['body']

        env = {
          REQUEST_METHOD => event['httpMethod'],
          SCRIPT_NAME => '',
          PATH_INFO => event['path'] || '',
          QUERY_STRING => Rack::Utils.build_query(event['queryStringParameters'] || {}),
          SERVER_NAME => 'localhost',
          SERVER_PORT => 443,
          CONTENT_TYPE => event.fetch('headers', {}).delete('content-type'),
          RACK_VERSION => Rack::VERSION,
          RACK_INPUT => StringIO.new(body || ''),
          RACK_ERRORS => $stderr,
          RACK_URL_SCHEME => 'https',
          'lambda.context' => context
        }

        event.fetch('headers', {}).transform_keys { |key| "HTTP_#{key}" }

        env
      end
    end
  end
end
