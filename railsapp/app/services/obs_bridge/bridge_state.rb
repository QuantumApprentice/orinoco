# frozen_string_literal: true

require "time"

module ObsBridge
  class BridgeState
    def initialize(redis:, bridge_id:, clock: -> { Time.now.utc }, default_enabled: false)
      @redis = redis
      @keys = RedisKeys.new(bridge_id: bridge_id)
      @clock = clock
      @mutex = Mutex.new

      @desired_enabled = default_enabled
      @runtime_connected = false
      @runtime_state = "down"
      @capture_all_until = nil
      @last_error = nil
      @last_heartbeat_at = nil

      persist!
    end

    def desired_enabled?
      @mutex.synchronize { @desired_enabled }
    end

    def runtime_connected?
      @mutex.synchronize { @runtime_connected }
    end

    def runtime_state
      @mutex.synchronize { @runtime_state }
    end

    def capture_all_until
      @mutex.synchronize { @capture_all_until }
    end

    def capture_all_active?
      @mutex.synchronize do
        !!(@capture_all_until && @capture_all_until > now)
      end
    end

    def enable!
      @mutex.synchronize do
        @desired_enabled = true
        persist_locked!
      end
    end

    def disable!
      @mutex.synchronize do
        @desired_enabled = false
        persist_locked!
      end
    end

    def connected!
      @mutex.synchronize do
        @runtime_connected = true
        @runtime_state = "up"
        @last_error = nil
        persist_locked!
      end
    end

    def disconnected!(error: nil)
      @mutex.synchronize do
        @runtime_connected = false
        @runtime_state = "down"
        @last_error = error if error
        persist_locked!
      end
    end

    def capture_all_for(seconds)
      seconds = Integer(seconds)
      raise ArgumentError, "seconds must be positive" unless seconds.positive?

      @mutex.synchronize do
        new_deadline = now + seconds
        @capture_all_until = [@capture_all_until, new_deadline].compact.max
        persist_locked!
      end
    end

    def clear_capture_all!
      @mutex.synchronize do
        @capture_all_until = nil
        persist_locked!
      end
    end

    def set_last_error!(message)
      @mutex.synchronize do
        @last_error = message.to_s
        persist_locked!
      end
    end

    def clear_last_error!
      @mutex.synchronize do
        @last_error = nil
        persist_locked!
      end
    end

    def heartbeat!
      @mutex.synchronize do
        @last_heartbeat_at = now
        persist_locked!
      end
    end

    def snapshot
      @mutex.synchronize { snapshot_locked }
    end

    private

    def persist!
      @mutex.synchronize { persist_locked! }
    end

    def persist_locked!
      payload = snapshot_locked

      @redis.pipelined do |pipe|
        payload.each do |field, value|
          pipe.hset(@keys.status, field, value)
        end
      end
    end

    def snapshot_locked
      current_time = now

      {
        "bridge_id" => @keys.bridge_id,
        "desired_state" => @desired_enabled ? "enabled" : "disabled",
        "runtime_state" => @runtime_state,
        "connected" => boolean_string(@runtime_connected),
        "capture_all_until" => iso8601_or_blank(@capture_all_until),
        # Useful for the UI, but the authoritative value is capture_all_until.
        "capture_all_active" => boolean_string(@capture_all_until && @capture_all_until > current_time),
        "last_error" => @last_error.to_s,
        "last_heartbeat_at" => iso8601_or_blank(@last_heartbeat_at),
        "updated_at" => current_time.iso8601(6)
      }
    end

    def now
      value = @clock.call
      value.utc
    end

    def iso8601_or_blank(value)
      value ? value.utc.iso8601(6) : ""
    end

    def boolean_string(value)
      value ? "true" : "false"
    end
  end
end
