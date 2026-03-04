# frozen_string_literal: true
require 'json'
require 'publikes/current'
require 'publikes/batch'

module Publikes
  class Enumerate
    def initialize(environment:)
      @environment = environment
    end

    def env; @environment; end

    def each_batch(&block)
      return enum_for(:each_batch) unless block_given?

      current = Publikes::Current.new(environment: env)
      batch_id = current.value[:head]

      while batch_id
        batch = Publikes::Batch.get(batch_id, env:)
        yield batch, batch.fetch(:pages)
        batch_id = batch[:next]
      end
    end

    def each_page(&block)
      return enum_for(:each_page) unless block_given?

      each_batch do |_batch, page_ids|
        page_ids.each do |page_id|
          page = JSON.parse(
            env.s3.get_object(bucket: env.s3_bucket, key: "data/public/pages/#{page_id}.json").body.read,
            symbolize_names: true,
          )
          yield page
        end
      end
    end
  end
end
