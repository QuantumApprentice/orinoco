# frozen_string_literal: true

require "rails_helper"
require "json"

RSpec.describe ObsBridge::InventoryStore do



  let(:redis) { instance_double(Redis) }
  let(:pipe) { instance_double(Redis) }
  let(:clock_state) { Struct.new(:now).new(Time.utc(2026, 3, 23, 18, 0, 0)) }
  let(:clock) { -> { clock_state.now } }
  let(:keys) { ObsBridge::RedisKeys.new(bridge_id: "main") }
  let(:broadcaster) { instance_double(ObsBridge::StatusBroadcaster, broadcast!: true) }

  before do
    allow(redis).to receive(:get).and_return(nil)
    allow(redis).to receive(:pipelined).and_yield(pipe)

    allow(pipe).to receive(:set)
    allow(pipe).to receive(:del)
    allow(pipe).to receive(:hset)

    allow(ObsBridge::StatusBroadcaster).to receive(:new).and_return(broadcaster)
  end

  subject(:store) do
    described_class.new(
      redis: redis,
      bridge_id: "main",
      clock: clock
    )
  end

  before do
    allow(redis).to receive(:get).and_return(nil)
    allow(redis).to receive(:pipelined).and_yield(pipe)

    allow(pipe).to receive(:set)
    allow(pipe).to receive(:del)
    allow(pipe).to receive(:hset)
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

    expect(pipe).to have_received(:set).with(
      keys.scenes,
      [
        { sceneName: "Clips" },
        { sceneName: "Starting Soon" }
      ].to_json
    )

    expect(pipe).to have_received(:set).with(
      keys.scene_items("Clips"),
      [
        { sceneItemId: 11, sourceName: "fight", enabled: true }
      ].to_json
    )

    expect(pipe).to have_received(:set).with(
      keys.scene_items("Starting Soon"),
      [
        { sceneItemId: 21, sourceName: "countdown", enabled: true }
      ].to_json
    )

    expect(pipe).to have_received(:hset).with(
      keys.status,
      "inventory_refreshed_at",
      "2026-03-23T18:00:00.000000Z"
    )

    expect(pipe).to have_received(:hset).with(
      keys.status,
      "inventory_scene_count",
      "2"
    )
  end

  it "writes empty arrays for scenes without provided items" do
    store.write_snapshot!(
      scenes: [
        { sceneName: "Clips" }
      ],
      scene_items_by_scene: {}
    )

    expect(pipe).to have_received(:set).with(
      keys.scene_items("Clips"),
      [].to_json
    )
  end

  it "removes stale scene item keys when the inventory changes" do
    allow(redis).to receive(:get).with(keys.scenes).and_return(
      nil,
      [{ sceneName: "Old Scene" }].to_json
    )

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

    expect(pipe).to have_received(:del).with(keys.scene_items("Old Scene"))
    expect(pipe).to have_received(:set).with(
      keys.scene_items("New Scene"),
      [
        { sceneItemId: 2, sourceName: "fresh" }
      ].to_json
    )

    expect(pipe).to have_received(:hset).with(
      keys.status,
      "inventory_refreshed_at",
      "2026-03-23T18:00:10.000000Z"
    )
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

    expect(pipe).to have_received(:set).with(
      keys.scenes,
      ["Clips"].to_json
    )

    expect(pipe).to have_received(:set).with(
      keys.scene_items("Clips"),
      [
        { sceneItemId: 5, sourceName: "fight" }
      ].to_json
    )
  end

  it "raises when a scene entry has no usable name" do
    expect do
      store.write_snapshot!(
        scenes: [{ nonsense: "???" }],
        scene_items_by_scene: {}
      )
    end.to raise_error(ArgumentError, /scene must have a name/)
  end
end
