# frozen_string_literal: true
$stdout.sync = true

require 'publikes/environment'
require 'publikes/close_batch_action'
require 'publikes/determine_mergeability_action'
require 'publikes/ingest_endpoint'
require 'publikes/insert_status_action'
require 'publikes/merge_batch_action'
require 'publikes/store_status_action'

require 'json'

module Publikes
  module LambdaHandler
    def self.sqs_handler(event:, context:)
      Publikes::InsertStatusAction.new(
        environment:,
        statuses: event.fetch('Records').map do |r|
          body = JSON.parse(r.fetch('body'))
          puts(JSON.generate(sqs_record: body))
          {
            id: body.fetch('id'),
            ts: body.fetch('ts'),
          }
        end,
      ).perform
    end

    def self.http_handler(event:, context:)
      Publikes::IngestEndpoint.new(environment:, event:).respond
    end

    def self.action_handler(event:, context:)
      case event.fetch('publikes_action')
      when 'store_status'
        store_status(event:, context:)
      when 'determine_mergeability'
        determine_mergeability(event:, context:)
      when 'close_batch'
        close_batch(event:, context:)
      when 'merge_batch'
        merge_batch(event:, context:)
      end
    end
    
    def self.store_status(event:, context:)
      Publikes::StoreStatusAction.new(
        environment:,
        status_id: event.fetch('status_id'),
      ).perform
    end

    def self.determine_mergeability(event:, context:)
      Publikes::DetermineMergeabilityAction.new(
        environment:,
      ).perform
    end

    def self.close_batch(event:, context:)
      Publikes::CloseBatchAction.new(
        environment:,
      ).perform
    end

    def self.merge_batch(event:, context:)
      Publikes::MergeBatchAction.new(
        environment:,
        batch_id: event.fetch('batch_id'),
      ).perform
    end
    
    def self.environment
      @environment ||= Publikes::Environment.from_os
    end
  end
end
