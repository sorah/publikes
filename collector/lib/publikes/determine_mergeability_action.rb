# frozen_string_literal: true
require 'json'
require 'aws-sdk-s3'

require 'publikes/current'
require 'publikes/batch'

module Publikes
  class DetermineMergeabilityAction
    def initialize(environment:)
      @environment = environment

      @current = Publikes::Current.new(environment:)
    end

    def env; @environment; end
    attr_reader :current

    def perform
      batch_id = @current.value[:head]
      unless batch_id
        return { mergeability: false, batch_id: }
      end

      batch = Publikes::Batch.get(batch_id, env:)
      raise "head #{batch_id.inspect} is not head" unless batch[:head]

      return {
        batch_id:,
        mergeable: Publikes::Batch.mergeable?(batch, env:),
      }
    end
  end
end
