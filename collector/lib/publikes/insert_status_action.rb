# frozen_string_literal: true
require 'json'
require 'aws-sdk-s3'

require 'publikes/current'
require 'publikes/batch'
require 'publikes/errors'

module Publikes
  class InsertStatusAction
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
      rescue Publikes::Errors::NeedRetry => e
        env.logger.warn(e.inspect)
        sleep(rand(5000)/1000.0)
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
      unless current.value[:head]
        current.update(head: batch_id)
        sleep(rand(3000)/1000.0)
        raise Publikes::Errors::NeedRetry if Publikes::Current.new(environment: env).value[:head] != batch_id
      end

      new_statuses = statuses.reject do |s|
        env.s3.head_object(bucket: env.s3_bucket, key: "data/public/statuses/#{s.fetch(:id)}.json")
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
        nil
      end

      batch = begin
        Publikes::Batch.get(batch_id, env:)
      rescue Aws::S3::Errors::NoSuchKey
        Publikes::Batch.empty(id: batch_id, head: true, next: nil)
      end

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

      Publikes::Batch.put(batch, env:)

      {
        new_statuses:,
        batch_id:,
      }
    end
  end
end
