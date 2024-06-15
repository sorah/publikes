require 'json'
require 'open-uri'
require 'aws-sdk-s3'

module Publikes
  class StoreStatusAction
    def initialize(environment:, status_id:)
      @environment = environment
      @status_id = status_id.to_s

      raise ArgumentError, "invalid status_id" unless @status_id.match?(/\A[0-9a-zA-Z]+\z/)
    end

    attr_reader :status_id
    def env; @environment; end

    USER_AGENT = 'Publikes-Crawler (+https://github.com/sorah/publikes)'

    def perform
      key = "data/private/statuses/#{status_id}.json"
      data = begin
        JSON.parse(
          env.s3.get_object(
            bucket: env.s3_bucket,
            key:,
          ).body.read,
          symbolize_names: true,
        )
      rescue Aws::S3::Errors::NoSuchKey
        {
          id: status_id.to_s,
          complete: false,
          graphql_data: nil,
          fxtwitter_data: nil,
          saved_at: nil,
        }
      end

      fxtwitter_data = begin
        JSON.parse(URI.open("https://api.fxtwitter.com/status/#{status_id}", "User-Agent" => USER_AGENT, &:read))
      rescue OpenURI::HTTPError => e
        code = e.io.status[0]
        raise unless code == '404' || code == '403' || code == '401'
      end

      new_data = data.merge(
        complete: true,
        saved_at: Time.now.to_i,
        fxtwitter_data: fxtwitter_data || data[:fxtwitter_data],
      )

      env.s3.put_object(
        bucket: env.s3_bucket,
        key:,
        content_type: "application/json; charset=utf-8",
        body: JSON.generate(new_data),
      )

      {
        status_id:,
      }
    end
  end
end
