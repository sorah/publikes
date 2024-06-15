# frozen_string_literal: true
require 'json'
require 'aws-sdk-s3'

require 'publikes/current'
require 'publikes/batch'

module Publikes
  class InsertStatusAction
    class NeedRetry < StandardError; end

    def initialize(environment:, statuses:, timestamp: Time.now.to_i)
      @environment = environment
      @statuses = statuses # [{id:, ts:}], old to new

      @current = Publikes::Current.new(environment:)
      @timestamp = timestamp
    end

    def env; @environment; end
    attr_reader :statuses
    attr_reader :current
    attr_reader :timestamp

    def perform
      retval = nil

      begin
        retval = perform_inner()
      rescue NeedRetry => e
        env.logger.warn(e.inspect)
        retry
      end

      if env.state_machine_arn_store_status
        retval[:new_statuses].each do |s|
          env.states.start_execution(
            state_machine_arn: env.state_machine_arn_store_status,
            name: "status-#{s.fetch(:id)}",
            input: JSON.generate({status_id: s.fetch(:id)}),
          )
        rescue Aws::States::Errors::ExecutionAlreadyExists
        end
      end

      retval
    end

    def perform_inner
      batch_id = current.value[:head] || Publikes::Batch.make_id('-auto')
      batch_key =  "data/public/batches/#{batch_id}.json"

      new_statuses = statuses.reject do |s|
        env.s3.head_object(bucket: env.s3_bucket, key: "data/public/statuses/#{s.fetch(:id)}.json")
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
        nil
      end

      batch = begin
        JSON.parse(
          env.s3.get_object(
            bucket: env.s3_bucket,
            key: batch_key,
          ).body.read,
          symbolize_names: true,
        )
      rescue Aws::S3::Errors::NoSuchKey
        Publikes::Batch.empty(id: batch_id, head: true, next: nil)
      end
      raise "batch_id inconsistency #{batch_id.inspect}, #{batch[:id].inspect}" unless batch_id == batch[:id]

      new_pages = new_statuses.map do |s|
        page_id = "head/#{batch_id}/#{s.fetch(:id)}"
        env.s3.put_object(
          bucket: env.s3_bucket,
          key: "data/public/pages/#{page_id}.json",
          content_type: "application/json; charset=utf-8",
          body: JSON.generate({
            id: page_id,
            statuses: [s],
            created_at: timestamp,
          }),
        )
        page_id
      end

      # new to old
      batch[:pages].reverse! # old to new
      batch[:pages].push(*new_pages) # old to new
      batch[:pages].uniq! # old to new
      batch[:pages].reverse! # new to old

      nonce = SecureRandom.urlsafe_base64(32)
      batch[:update_nonce] = nonce

      env.s3.put_object(
        bucket: env.s3_bucket,
        key: batch_key,
        content_type: "application/json; charset=utf-8",
        body: JSON.generate(batch),
      )
      unless current.value[:head]
        current.update(head: batch_id)
      end

      sleep(rand(3000)/1000.0)
      updated_batch = JSON.parse(env.s3.get_object(bucket: env.s3_bucket, key: batch_key).body.read, symbolize_names: true)
      raise NeedRetry if updated_batch[:update_nonce] != nonce

      {
        new_statuses:,
        batch_id:,
      }
    end
  end
end
