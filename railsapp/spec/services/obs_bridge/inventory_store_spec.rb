# frozen_string_literal: true

require "rails_helper"
require "json"

RSpec.describe ObsBridge::InventoryStore do
  let(:redis) { FakeRedis.new }
  let(:clock_state) { Struct.new(:now).new(Time.utc(2026, 3, 23, 18, 0, 0)) }
  let(:clock) { -> { clock_state.now } }
  let(:keys) { ObsBridge::RedisKeys.new(bridge_id: "main") }

  subject(:store) do
    described_class.new(
      redis: redis,
      bridge_id: "main",
      clock: clock
    )
  end

  def stored_scenes
    JSON.parse(redis.get(keys.scenes))
  end

  def stored_items(scene_name)
    JSON.parse(redis.get(keys.scene_items(scene_name)))
  end

  def status
    redis.hgetall(keys.status)
  end

  it "writes scenes and per-scene items into redis" do
    store.write_snapshot!(
      scenes: [
        { sceneName: "Clips" },
        { sceneName: "Starting Soon" }
      ],
      scene_items_by_scene: {
        "Clips" => [
          { sceneItemId: 11, sourceName: "fight", enabled: true }
        ],
        "Starting Soon" => [
          { sceneItemId: 21, sourceName: "countdown", enabled: true }
        ]
      }
    )

    expect(stored_scenes).to eq(
      [
        { "sceneName" => "Clips" },
        { "sceneName" => "Starting Soon" }
      ]
    )

    expect(stored_items("Clips")).to eq(
      [
        { "sceneItemId" => 11, "sourceName" => "fight", "enabled" => true }
      ]
    )

    expect(stored_items("Starting Soon")).to eq(
      [
        { "sceneItemId" => 21, "sourceName" => "countdown", "enabled" => true }
      ]
    )

    expect(status).to include(
      "inventory_refreshed_at" => "2026-03-23T18:00:00.000000Z",
      "inventory_scene_count" => "2"
    )
  end

  it "writes empty arrays for scenes without provided items" do
    store.write_snapshot!(
      scenes: [
        { sceneName: "Clips" }
      ],
      scene_items_by_scene: {}
    )

    expect(stored_items("Clips")).to eq([])
  end

  it "removes stale scene item keys when the inventory changes" do
    store.write_snapshot!(
      scenes: [
        { sceneName: "Old Scene" }
      ],
      scene_items_by_scene: {
        "Old Scene" => [
          { sceneItemId: 1, sourceName: "legacy" }
        ]
      }
    )

    expect(redis.get(keys.scene_items("Old Scene"))).not_to be_nil

    clock_state.now += 10

    store.write_snapshot!(
      scenes: [
        { sceneName: "New Scene" }
      ],
      scene_items_by_scene: {
        "New Scene" => [
          { sceneItemId: 2, sourceName: "fresh" }
        ]
      }
    )

    expect(redis.get(keys.scene_items("Old Scene"))).to be_nil
    expect(stored_items("New Scene")).to eq(
      [
        { "sceneItemId" => 2, "sourceName" => "fresh" }
      ]
    )
    expect(status["inventory_refreshed_at"]).to eq("2026-03-23T18:00:10.000000Z")
  end

  it "accepts simple string scene entries too" do
    store.write_snapshot!(
      scenes: ["Clips"],
      scene_items_by_scene: {
        "Clips" => [
          { sceneItemId: 5, sourceName: "fight" }
        ]
      }
    )

    expect(stored_scenes).to eq(["Clips"])
    expect(stored_items("Clips")).to eq(
      [
        { "sceneItemId" => 5, "sourceName" => "fight" }
      ]
    )
  end

  it "raises when a scene entry has no usable name" do
    expect do
      store.write_snapshot!(
        scenes: [{ nonsense: "??? " }],
        scene_items_by_scene: {}
      )
    end.to raise_error(ArgumentError, /scene must have a name/)
  end
end
