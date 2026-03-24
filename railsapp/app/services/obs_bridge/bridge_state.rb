# frozen_string_literal: true

require "time"

module ObsBridge
  class BridgeState
    def initialize(redis:, bridge_id:, clock: -> { Time.now.utc }, default_enabled: false, status_writer: nil)
      @bridge_id = bridge_id
      @keys = RedisKeys.new(bridge_id: bridge_id)
      @status_writer = status_writer || ObsBridge::StatusWriter.new(redis: redis, bridge_id: bridge_id)

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
      mutate_and_persist! { @desired_enabled = true }
    end

    def disable!
      mutate_and_persist! { @desired_enabled = false }
    end

    def connected!
      mutate_and_persist! do
        @runtime_connected = true
        @runtime_state = "up"
        @last_error = nil
      end
    end

    def disconnected!(error: nil)
      mutate_and_persist! do
        @runtime_connected = false
        @runtime_state = "down"
        @last_error = error if error
      end
    end

    def capture_all_for(seconds)
      seconds = Integer(seconds)
      raise ArgumentError, "seconds must be positive" unless seconds.positive?

      mutate_and_persist! do
        new_deadline = now + seconds
        @capture_all_until = [@capture_all_until, new_deadline].compact.max
      end
    end

    def clear_capture_all!
      mutate_and_persist! { @capture_all_until = nil }
    end

    def set_last_error!(message)
      mutate_and_persist! { @last_error = message.to_s }
    end

    def clear_last_error!
      mutate_and_persist! { @last_error = nil }
    end

    def heartbeat!
      mutate_and_persist! { @last_heartbeat_at = now }
    end

    def snapshot
      @mutex.synchronize { snapshot_locked }
    end

    private

    def persist!
      payload = @mutex.synchronize { snapshot_locked }
      @status_writer.write_snapshot(payload)
    end

    def mutate_and_persist!
      payload = @mutex.synchronize do
        yield
        snapshot_locked
      end

      @status_writer.write_snapshot(payload)
    end

    def snapshot_locked
      current_time = now

      {
        "bridge_id" => @keys.bridge_id,
        "desired_state" => @desired_enabled ? "enabled" : "disabled",
        "runtime_state" => @runtime_state,
        "connected" => boolean_string(@runtime_connected),
        "capture_all_until" => iso8601_or_blank(@capture_all_until),
        "capture_all_active" => boolean_string(@capture_all_until && @capture_all_until > current_time),
        "last_error" => @last_error.to_s,
        "last_heartbeat_at" => iso8601_or_blank(@last_heartbeat_at),
        "updated_at" => current_time.iso8601(6)
      }
    end

    def now
      @clock.call.utc
    end

    def iso8601_or_blank(value)
      value ? value.utc.iso8601(6) : ""
    end

    def boolean_string(value)
      value ? "true" : "false"
    end
  end
end
