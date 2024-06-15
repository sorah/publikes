# frozen_string_literal: true
module Publikes
  module Batch
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
  end
end
