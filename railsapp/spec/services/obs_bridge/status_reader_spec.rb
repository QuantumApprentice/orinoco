# frozen_string_literal: true

require "spec_helper"
require "obs_bridge/status_reader"

RSpec.describe ObsBridge::StatusReader do
  let(:redis) { instance_double(Redis) }
  let(:keys) { ObsBridge::RedisKeys.new(bridge_id: "main") }

  subject(:reader) do
    described_class.new(
      redis: redis,
      bridge_id: "main"
    )
  end

  before do
    allow(redis).to receive(:hgetall).with(keys.status).and_return({})
    allow(redis).to receive(:get).with(keys.scenes).and_return(nil)
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
    allow(redis).to receive(:hgetall).with(keys.status).and_return(
      {
        "bridge_id" => "main",
        "desired_state" => "enabled",
        "runtime_state" => "up",
        "connected" => "true",
        "capture_all_active" => "true",
        "capture_all_until" => "2026-03-23T18:15:00Z",
        "inventory_scene_count" => "1",
        "last_error" => ""
      }
    )

    allow(redis).to receive(:get).with(keys.scenes).and_return(
      '[{"sceneName":"Clips"}]'
    )

    allow(redis).to receive(:get).with(keys.scene_items("Clips")).and_return(
      '[{"sceneItemId":1,"sourceName":"fight","sceneItemEnabled":true}]'
    )

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
