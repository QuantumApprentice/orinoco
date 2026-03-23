# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::StatusReader do
  let(:redis) { FakeRedis.new }
  let(:keys) { ObsBridge::RedisKeys.new(bridge_id: "main") }

  subject(:reader) do
    described_class.new(
      redis: redis,
      bridge_id: "main"
    )
  end

  it "returns sensible defaults when redis is empty" do
    snapshot = reader.snapshot

    expect(snapshot[:bridge_id]).to eq("main")
    expect(snapshot[:status]).to include(
      bridge_id: "main",
      desired_state: "disabled",
      runtime_state: "down",
      connected: false,
      capture_all_active: false,
      inventory_scene_count: 0
    )
    expect(snapshot[:scenes]).to eq([])
  end

  it "reads status, scenes, and scene items from redis" do
    redis.hset(keys.status, "bridge_id", "main")
    redis.hset(keys.status, "desired_state", "enabled")
    redis.hset(keys.status, "runtime_state", "up")
    redis.hset(keys.status, "connected", "true")
    redis.hset(keys.status, "capture_all_active", "true")
    redis.hset(keys.status, "capture_all_until", "2026-03-23T18:15:00Z")
    redis.hset(keys.status, "inventory_scene_count", "1")
    redis.hset(keys.status, "last_error", "")
    redis.set(keys.scenes, '[{"sceneName":"Clips"}]')
    redis.set(keys.scene_items("Clips"), '[{"sceneItemId":1,"sourceName":"fight","sceneItemEnabled":true}]')

    snapshot = reader.snapshot

    expect(snapshot[:status]).to include(
      desired_state: "enabled",
      runtime_state: "up",
      connected: true,
      capture_all_active: true,
      inventory_scene_count: 1
    )

    expect(snapshot[:status][:capture_all_until]).to eq(Time.iso8601("2026-03-23T18:15:00Z"))

    expect(snapshot[:scenes]).to eq(
      [
        {
          "sceneName" => "Clips",
          "raw" => { "sceneName" => "Clips" },
          "items" => [
            { "sceneItemId" => 1, "sourceName" => "fight", "sceneItemEnabled" => true }
          ]
        }
      ]
    )
  end
end
