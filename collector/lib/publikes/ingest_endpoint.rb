# frozen_string_literal: true
require 'aws-sdk-sqs'
require 'openssl'
require 'json'

module Publikes
  class IngestEndpoint
    def initialize(environment:, event:)
      @environment = environment
      @event = event
      @request = Request.from_fn_url_event(event)
      @meta = {}
    end

    attr_reader :request

    Request = Struct.new(:method, :path, :query, :headers, :body, keyword_init: true) do
      def self.from_fn_url_event(event)
        body = event['isBase64Encoded'] ? event.fetch('body').unpack1('m*') : event.fetch('body', '')
        new(
          method: event.dig('requestContext', 'http', 'method'),
          path: event.dig('requestContext', 'http', 'path'),
          query: event.fetch('queryStringParameters', {}),
          headers: event.fetch('headers'),
          body: body,
        )
      end

      def content_type
        headers['content-type']
      end

      def json
        raise Error.new(400, 'not a json request') unless content_type&.match?(%r{\Aapplication/json(?:;.*)?\z})
        @json ||= JSON.parse(body)
      rescue JSON::ParserError => e
        raise Error.new(400, e.inspect)
      end
    end

    Response = Struct.new(:status, :headers, :body, :meta, keyword_init: true) do
      def as_json
        {
          'cookies' => [],
          'isBase64Encoded' => false,
          'statusCode' => status,
          'headers' => headers,
          'body' => body,
        }
      end
    end


    class Error < StandardError
      def initialize(code, message)
        super(message)
        @code = code
      end

      def as_response
        Response.new(status: code, headers: { 'content-type' => 'application/json; charset=utf-8' }, body: "#{JSON.generate({ok: false, error: {code: code, message: message}})}\n", meta: {error: self.inspect, cause: self.cause&.inspect})
      end

      attr_reader :code
    end


    def respond
      begin
        begin
          ta = Time.now
          respond_inner()
        rescue NoMemoryError, ScriptError, SecurityError, SignalException, SystemExit, SystemStackError => e
          raise e
        rescue Error => e
          raise e
        rescue Exception => e
          $stderr.puts e.full_message
          raise Error.new(500, 'Internal Server Error')
        end
      rescue Error => e
        e.as_response
      end.tap do |response|
        puts JSON.generate(
         status: response.status,
          method: request.method,
          path: request.path,
          query: request.query.reject { |k,v| k.start_with?('secure_') },
          reqtime: Time.now.to_f - ta.to_f,
          meta: @meta.merge(response.meta || {}),
        )
      end.as_json
    end

    def respond_inner
      case [request.method, request.path]
      when ['POST', '/publikes-ingest']
        authorize!
        handle_ingest
      else
        Error.new(404, 'not found').as_response
      end
    end

    def authorize!
      unless OpenSSL.secure_compare(@environment.secret.fetch('ingest_secret'), request.headers['x-secret'] || '')
        raise Error.new(401, 'Unauthorized')
      end
    end

    def handle_ingest
      url = request.json['url']
      raise Error.new(400, 'missing url') if !url.is_a?(String) || url.empty?

      m = url.match(%r{\Ahttps?://(?:twitter|x)\.com/[^/]+/status(?:es)?/(\d+)})
      raise Error.new(400, 'invalid url') unless m
      id = m[1]
      puts(JSON.generate(action: 'send_message', url:, id:))
      @environment.sqs.send_message(
        queue_url: @environment.sqs_queue_url,
        message_body: JSON.generate({id:, ts: Time.now.to_i}),
      )

      Response.new(status: 200, headers: {'content-type' => 'application/json; charset=utf-8'}, body: '{"ok": true}', meta: {})
    end

  end
end
