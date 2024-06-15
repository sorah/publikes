# frozen_string_literal: true
require 'json'
require 'securerandom'
require 'aws-sdk-s3'

module Publikes
  class Lock
    class Occupied < StandardError; end

    def self.id_by_hostname(prefix)
      "#{prefix}/#{ENV['HOSTNAME'] || Socket.gethostname}/#{$$}/#{SecureRandom.urlsafe_base64(32)}"
    end

    def initialize(environment:, group:, id:)
      @environment = environment
      @group = group
      @id = id

      @key = nil
    end

    def env; @environment; end
    attr_reader :group
    attr_reader :id

    def key
      @key ||= "data/private/locks/#{group}"
    end

    def lock
      v = get(); raise Occupied, "#{key.inspect} is already occupied by #{v.inspect}" if v[:lock_id] && v[:lock_id] != id
      if v[:lock_id] == id
        env.logger.info "Lock: (already locked) #{key.inspect} = #{v.inspect}"
        return v
      end

      v = {lock_id: id}
      env.s3.put_object(
        bucket: env.s3_bucket,
        key:,
        content_type: "application/json; charset=utf-8",
        body: JSON.generate(v),
      )
      v = get(); raise Occupied, "Attempted to lock #{key.inspect} but occupied by #{v.inspect}" if v[:lock_id] && v[:lock_id] != id
      env.logger.info "Lock: (placed) #{key.inspect} = #{v.inspect}"
      v
    end

    def unlock
      v = get(); raise Occupied, "#{key.inspect} is not occupied by us (#{v.inspect})" if v[:lock_id] != id
      env.logger.info "Lock: (released) #{key.inspect} = #{v.inspect}"
      env.s3.delete_object(
        bucket: env.s3_bucket,
        key:,
      )
      nil
    end

    def with_lock
      lock
      yield
    ensure
      begin
        unlock
      rescue Occupied => e
        env.logger.warn "Lock#with_lock: ensure unlock failure: #{e.inspect}"
      end
    end

    private def get
      begin
        JSON.parse(
          env.s3.get_object(
            bucket: env.s3_bucket,
            key:,
          ).body.read,
          symbolize_names: true,
        )
      rescue Aws::S3::Errors::NoSuchKey
        {}
      end
    end
  end
end
