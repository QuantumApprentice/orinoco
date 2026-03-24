# app/services/obs_bridge/status_writer.rb
# frozen_string_literal: true

require "time"

module ObsBridge
  class StatusWriter
    def initialize(redis:, bridge_id:)
      @redis = redis
      @keys = RedisKeys.new(bridge_id: bridge_id)
    end

    def set_desired_state(desired_state)
      write_status(
        "bridge_id" => @keys.bridge_id,
        "desired_state" => desired_state,
        "updated_at" => timestamp
      )
    end

    def mark_start_requested
      set_desired_state("enabled")
    end

    def mark_stop_requested
      set_desired_state("disabled")
    end

    private

    def write_status(attributes)
      @redis.hset(@keys.status, attributes)
    end

    def timestamp
      Time.now.utc.iso8601
    end
  end
end
