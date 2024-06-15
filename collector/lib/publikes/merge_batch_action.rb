# frozen_string_literal: true
require 'json'
require 'aws-sdk-s3'

require 'publikes/current'
require 'publikes/batch'

module Publikes
  class MergeBatchAction
    MAX_ITEMS = 40

    def initialize(environment:, batch_id:, timestamp: Time.now.to_i)
      @environment = environment
      @batch_id = batch_id
      @timestamp = timestamp
    end

    def env; @environment; end
    attr_reader :batch_id
    attr_reader :timestamp

    def perform
      key = "data/public/batches/#{batch_id}.json"
      batch = JSON.parse(
        env.s3.get_object(
          bucket: env.s3_bucket,
          key:,
        ).body.read,
        symbolize_names: true,
      )
      raise "batch_id inconsistency" unless batch_id == batch[:id]
      raise "head=false, already merged?" unless batch[:head]

      # Merge pages
      item_ids = {}
      pending_items = []
      merged_pages = []
      batch.fetch(:pages).each do |page_id|
        page = JSON.parse(env.s3.get_object(bucket: env.s3_bucket, key: "data/public/pages/#{page_id}.json").body.read, symbolize_names: true)
        pending_items.concat(page.fetch(:statuses))
        if pending_items.size >= MAX_ITEMS
          merged_pages.push(create_page(merged_pages.size.succ, pending_items, item_ids))
          pending_items = []
        end
      end
      merged_pages.push(create_page(merged_pages.size.succ, pending_items, item_ids)) unless pending_items.empty?

      # Detect and collect missing items in batch
      missing_items = env.s3.list_objects_v2(bucket: env.s3_bucket, prefix: "data/public/pages/head/#{batch_id}/").flat_map(&:contents).reject do |content|
        id = content.key.split(?/).last.split(?.,2).first # head pages are numbered using status_id
        item_ids[id]
      end.flat_map do |missing_content|
        page = JSON.parse(env.s3.get_object(bucket: env.s3_bucket, key: missing_content.key).body.read, symbolize_names: true)
        page.fetch(:statuses)
      end
      merged_pages.unshift(create_page(0, missing_items, item_ids)) unless missing_items.empty?

      # Replace batch with merged pages
      env.s3.put_object(
        bucket: env.s3_bucket,
        key:,
        content_type: "application/json; charset=utf-8",
        cache_control: "public, max-age=604800",
        body: JSON.generate(batch.merge(
          head: false,
          pages: merged_pages,
          updated_at: timestamp,
        )),
      )

      # Delete head items
      env.s3.list_objects_v2(bucket: env.s3_bucket, prefix: "data/public/pages/head/#{batch_id}/").flat_map(&:contents).each do |content|
        env.s3.delete_object(bucket: env.s3_bucket, key: content.key)
      end

      {
        batch_id:
      }
    end

    private def create_page(pagenum, statuses, item_ids)
      id = "merged/#{batch_id}/#{'%06d' % pagenum}"
      env.s3.put_object(
        bucket: env.s3_bucket,
        key: "data/public/pages/#{id}.json",
        content_type: "application/json; charset=utf-8",
        cache_control: "public, max-age=604800",
        body: JSON.generate(
          id:,
          statuses:,
          created_at: timestamp,
        )
      )
      statuses.each do |s|
        item_ids[s[:id].to_s] = true
      end
      id
    end
  end
end
