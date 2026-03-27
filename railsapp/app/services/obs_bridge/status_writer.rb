# frozen_string_literal: true

class ObsBridge::StatusWriter
  def initialize(redis:, bridge_id:)
    @redis = redis
    @bridge_id = bridge_id
    @keys = ObsBridge::RedisKeys.new(bridge_id: bridge_id)
  end

  def write_snapshot(attributes)
    result = @redis.hset(@keys.status, attributes)
    broadcast_status_panel!
    result
  end

  def set_desired_state(desired_state)
    write_snapshot(
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

  def broadcast_status_panel!
    bridge_status = ObsBridge::StatusReader.new(
      redis: @redis,
      bridge_id: @bridge_id
    ).snapshot[:status]

    ObsBridge::StatusBroadcaster.new(redis: @redis, bridge_id: @bridge_id).broadcast!
  end

  def timestamp
    Time.now.utc.iso8601
  end
end
