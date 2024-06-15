# frozen_string_literal: true
require 'json'
require 'aws-sdk-s3'

module Publikes
  class Current
    KEY = "data/public/current.json"

    def initialize(environment:)
      @environment = environment
      @value = nil
      @value_was = nil
    end

    def env; @environment; end

    def value
      @value ||= begin
        JSON.parse(
          env.s3.get_object(
            bucket: env.s3_bucket,
            key: KEY,
          ).body.read,
          symbolize_names: true,
        )
      rescue Aws::S3::Errors::NoSuchKey
        {
          head: nil,
          last: nil,
          updated_at: 0,
        }
      end
    end

    def value_was
      @value_was
    end

    def update(hash)
      new_value = value.merge(hash)
      new_value[:updated_at] = Time.now.to_i
      env.s3.put_object(
        bucket: env.s3_bucket,
        key: KEY,
        content_type: "application/json; charset=utf-8",
        body: JSON.generate(new_value),
      )
      @value_was = value
      @value = new_value
    end
  end
end
