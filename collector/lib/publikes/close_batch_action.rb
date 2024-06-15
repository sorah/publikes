# frozen_string_literal: true
require 'json'
require 'aws-sdk-s3'

require 'publikes/current'
require 'publikes/batch'

module Publikes
  class CloseBatchAction
    def initialize(environment:)
      @environment = environment

      @current = Publikes::Current.new(environment:)
    end

    def env; @environment; end
    attr_reader :current

    def perform
      closing_head_id = @current.value[:head]
      new_head_id = Publikes::Batch.make_id('-auto')

      env.s3.put_object(
        bucket: env.s3_bucket,
        key: "data/public/batches/#{new_head_id}.json",
        content_type: "application/json; charset=utf-8",
        body: JSON.generate(Publikes::Batch.empty(id: new_head_id, head: true, next: closing_head_id)),
      )

      @current.update(
        head: new_head_id,
        last: closing_head_id,
      )

      {
        current: @current.value,
        current_was: @current.value_was,
        closed_head_id: closing_head_id,
        new_head_id:,
      }
    end
  end
end
