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

      batch = JSON.parse(
        env.s3.get_object(
          bucket: env.s3_bucket,
          key: "data/public/batches/#{batch_id}.json",
        ).body.read,
        symbolize_names: true,
      )
      raise "batch_id inconsistency #{batch_id.inspect}, #{batch[:id].inspect}" unless batch_id == batch[:id]
      raise "head #{batch_id.inspect} is not head" unless batch[:head]

      return {
        batch_id:,
        mergeable: (batch[:pages].size >= 7),
      }
    end
  end
end
