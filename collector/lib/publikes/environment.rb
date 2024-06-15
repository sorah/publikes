# frozen_string_literal: true
require 'logger'
require 'json'
require 'aws-sdk-s3'
require 'aws-sdk-secretsmanager'
require 'aws-sdk-sqs'
require 'aws-sdk-states'

module Publikes
  class Environment
    def initialize(s3_bucket:, sqs_queue_url:, secret_id:, state_machine_arn_store_status:)
      @s3_bucket = s3_bucket
      @sqs_queue_url = sqs_queue_url
      @secret_id = secret_id
      @state_machine_arn_store_status = state_machine_arn_store_status

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
      )
    end

    attr_reader :s3_bucket
    attr_reader :sqs_queue_url
    attr_reader :secret_id
    attr_reader :state_machine_arn_store_status

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
