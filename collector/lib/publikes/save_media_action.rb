require 'json'
require 'tempfile'
require 'aws-sdk-s3'

module Publikes
  class SaveMediaAction
    def initialize(environment:, status_id:)
      @environment = environment
      @status_id = status_id.to_s

      raise ArgumentError, "invalid status_id" unless @status_id.match?(/\A[0-9a-zA-Z]+\z/)
    end

    attr_reader :status_id
    def env; @environment; end

    USER_AGENT = 'Publikes-Crawler (+https://github.com/sorah/publikes)'

    CONTENT_TYPES = {
      'jpg' => 'image/jpeg',
      'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
    }.freeze

    def perform
      data = JSON.parse(
        env.s3.get_object(
          bucket: env.s3_bucket,
          key: "data/private/statuses/#{status_id}.json",
        ).body.read,
        symbolize_names: true,
      )

      media_items = data.dig(:fxtwitter_data, :tweet, :media, :all)
      return { status_id:, saved_keys: [] } if media_items.nil? || media_items.empty?

      photo_count = 0
      video_count = 0
      gif_count = 0
      index_entries = []

      media_items.each do |item|
        type = item[:type]
        case type
        when 'photo'
          photo_count += 1
          ext = photo_extension(item[:url])
          filename = "photo-#{photo_count}.#{ext}"
          content_type = CONTENT_TYPES.fetch(ext, 'application/octet-stream')
          source_url = item[:url]
        when 'video'
          video_count += 1
          filename = "video-#{video_count}.mp4"
          content_type = 'video/mp4'
          source_url = best_mp4_variant_url(item[:variants])
        when 'gif'
          gif_count += 1
          filename = "gif-#{gif_count}.mp4"
          content_type = 'video/mp4'
          source_url = best_mp4_variant_url(item[:variants])
        else
          next
        end

        next unless source_url

        key = "data/private/media/#{status_id}/#{filename}"
        Tempfile.create(["publikes-media-", ".#{File.extname(filename)}"], binmode: true) do |tmpfile|
          download_to(source_url, tmpfile.path)
          tmpfile.rewind
          env.s3.put_object(
            bucket: env.s3_bucket,
            key:,
            content_type:,
            body: tmpfile,
          )
        end

        index_entries << {
          key:,
          source_url:,
          filename:,
          original: item,
        }
      end

      saved_keys = index_entries.map { |e| e[:key] }

      index = {
        status_id:,
        media: index_entries,
      }
      index_key = "data/private/media/#{status_id}/index.json"
      env.s3.put_object(
        bucket: env.s3_bucket,
        key: index_key,
        content_type: 'application/json; charset=utf-8',
        body: JSON.generate(index),
      )

      { status_id:, saved_keys: saved_keys + [index_key] }
    end

    private

    def download_to(url, path)
      system("curl", "-sSfL", "-o", path, "-A", USER_AGENT, "--", url, exception: true)
    end

    def photo_extension(url)
      path = URI.parse(url).path
      ext = File.extname(path).delete_prefix('.')
      ext.empty? ? 'jpg' : ext
    end

    def best_mp4_variant_url(variants)
      return nil if variants.nil? || variants.empty?

      mp4s = variants.select { |v| v[:content_type] == 'video/mp4' }
      return nil if mp4s.empty?

      mp4s.max_by { |v| v[:bitrate] || 0 }[:url]
    end
  end
end
