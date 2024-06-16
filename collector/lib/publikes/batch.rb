# frozen_string_literal: true
require 'json'
require 'publikes/errors'

module Publikes
  module Batch
    def self.key(id)
       "data/public/batches/#{id}.json"
    end

    def self.make_id(suffix=nil)
      "#{(Time.now.to_f*10000).round}#{suffix}"
    end

    def self.empty(id:, head: true, next: nil)
      ts = Time.now.to_i
      {
        id:,
        head:,
        pages: [],
        next:,
        created_at: ts,
        updated_at: ts,
      }
    end

    def self.get(id, env:)
      batch = JSON.parse(
        env.s3.get_object(
          bucket: env.s3_bucket,
          key: key(id),
        ).body.read,
        symbolize_names: true,
      )
      raise "batch_id inconsistency #{id.inspect}, #{batch[:id].inspect}" unless id == batch[:id]
      batch
    end

    def self.put(batch, env:, verify: true, cache_control: nil)
      if verify
        nonce = SecureRandom.urlsafe_base64(32)
        batch[:update_nonce] = nonce
      end
      batch[:updated_at] = Time.now.to_i
      retval = env.s3.put_object(
        bucket: env.s3_bucket,
        key: key(batch.fetch(:id)),
        content_type: "application/json; charset=utf-8",
        cache_control:,
        body: JSON.generate(batch),
      )
      if verify
        sleep(rand(3000)/1000.0)
        updated_batch = get(batch[:id], env:)
        raise Publikes::Errors::NeedRetry if updated_batch[:update_nonce] != nonce
      end
      retval
    end

    def self.mergeable?(batch, env:)
      batch[:head] && batch[:pages].size >= env.max_items_in_head
    end
  end
end
