# frozen_string_literal: true
require 'logger'
require 'json'
require 'aws-sdk-s3'
require 'aws-sdk-secretsmanager'
require 'aws-sdk-sqs'
require 'aws-sdk-states'

module Publikes
  class Environment
    def initialize(s3_bucket:, sqs_queue_url: nil, secret_id: nil, state_machine_arn_store_status: nil, state_machine_arn_rotate_batch: nil, max_items_per_page: nil, max_items_in_head: nil)
      @s3_bucket = s3_bucket
      @sqs_queue_url = sqs_queue_url
      @secret_id = secret_id
      @state_machine_arn_store_status = state_machine_arn_store_status
      @state_machine_arn_rotate_batch = state_machine_arn_rotate_batch

      @max_items_per_page = max_items_per_page || 10
      @max_items_in_head = max_items_in_head || 20

      @s3 = nil
      @secretsmanager = nil
      @sqs = nil
      @states = nil

      @secret = nil

      @logger = Logger.new($stdout)
    end

    def self.from_os
      new(
        s3_bucket: ENV.fetch('S3_BUCKET'),
        sqs_queue_url: ENV['SQS_QUEUE_URL'],
        secret_id: ENV['SECRET_ID'],
        state_machine_arn_store_status: ENV['STATE_MACHINE_ARN_STORE_STATUS'],
        state_machine_arn_rotate_batch: ENV['STATE_MACHINE_ARN_ROTATE_BATCH'],
        max_items_per_page: ENV['MAX_ITEMS_PER_PAGE']&.to_i,
        max_items_in_head: ENV['MAX_ITEMS_IN_HEAD']&.to_i,
      )
    end

    attr_reader :s3_bucket
    attr_reader :sqs_queue_url
    attr_reader :secret_id
    attr_reader :state_machine_arn_store_status
    attr_reader :state_machine_arn_rotate_batch

    attr_reader :max_items_per_page
    attr_reader :max_items_in_head

    def s3
      @s3 ||= Aws::S3::Client.new(logger:)
    end

    def secretsmanager
      @secretsmanager ||= Aws::SecretsManager::Client.new(logger:)
    end

    def sqs
      @sqs ||= Aws::SQS::Client.new(logger:)
    end

    def states
      @states ||= Aws::States::Client.new(logger:)
    end

    def secret
      @secret ||= JSON.parse(secretsmanager.get_secret_value(secret_id:).secret_string)
    end

    def logger
      @logger
    end
  end
end
