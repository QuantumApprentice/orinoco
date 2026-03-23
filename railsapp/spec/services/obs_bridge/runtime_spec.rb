# frozen_string_literal: true

require "rails_helper"
require "json"

RSpec.describe ObsBridge::Runtime do
  class FakeSession
    attr_reader :fetch_inventory_calls, :pump_calls

    def initialize(inventory:, pump_error: nil)
      @inventory = inventory
      @pump_error = pump_error
      @fetch_inventory_calls = 0
      @pump_calls = 0
    end

    def fetch_inventory
      @fetch_inventory_calls += 1
      @inventory
    end

    def pump_once(timeout:)
      @pump_calls += 1
      raise @pump_error if @pump_error
      sleep timeout
    end
  end

  class FakeSessionRunner
    attr_reader :run_calls

    def initialize(sessions: [], errors: [])
      @sessions = sessions.dup
      @errors = errors.dup
      @run_calls = 0
    end

    def run
      @run_calls += 1

      error = @errors.shift
      raise error if error

      session = @sessions.shift || raise("no fake session available")
      yield session
    end
  end

  let(:redis) { FakeRedis.new }
  let(:keys) { ObsBridge::RedisKeys.new(bridge_id: "main") }
  let(:clock_state) { Struct.new(:now).new(Time.utc(2026, 3, 23, 18, 0, 0)) }
  let(:clock) { -> { clock_state.now } }
  let(:mono_state) { Struct.new(:value).new(0.0) }
  let(:monotonic_clock) { -> { mono_state.value } }
  let(:sleeper) do
    lambda do |seconds|
      mono_state.value += seconds
      clock_state.now += seconds
      sleep(seconds / 50.0)
    end
  end

  let(:state) do
    ObsBridge::BridgeState.new(
      redis: redis,
      bridge_id: "main",
      clock: clock,
      default_enabled: false
    )
  end

  let(:inventory_store) do
    ObsBridge::InventoryStore.new(
      redis: redis,
      bridge_id: "main",
      clock: clock
    )
  end

  def status
    redis.hgetall(keys.status)
  end

  def stored_scenes
    raw = redis.get(keys.scenes)
    raw ? JSON.parse(raw) : nil
  end

  def stored_items(scene_name)
    raw = redis.get(keys.scene_items(scene_name))
    raw ? JSON.parse(raw) : nil
  end

  def wait_until(timeout: 1.5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    loop do
      return true if yield
      raise "timed out waiting for condition" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.01
    end
  end

  it "connects, marks state up, and hydrates inventory on start" do
    session = FakeSession.new(
      inventory: {
        scenes: [{ "sceneName" => "Clips" }],
        scene_items_by_scene: {
          "Clips" => [{ "sceneItemId" => 1, "sourceName" => "fight", "sceneItemEnabled" => true }]
        }
      }
    )

    runtime = described_class.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: FakeSessionRunner.new(sessions: [session]),
      heartbeat_interval: 10.0,
      idle_sleep: 0.05,
      monotonic_clock: monotonic_clock,
      sleeper: sleeper
    )

    runtime.start!

    wait_until { state.runtime_connected? }
    wait_until { stored_scenes == [{ "sceneName" => "Clips" }] }

    expect(runtime.running?).to be(true)
    expect(status["runtime_state"]).to eq("up")
    expect(status["connected"]).to eq("true")
    expect(stored_items("Clips")).to eq(
      [{ "sceneItemId" => 1, "sourceName" => "fight", "sceneItemEnabled" => true }]
    )

    runtime.stop!
    wait_until { !runtime.running? }
  end

  it "refreshes inventory on demand" do
    session = FakeSession.new(
      inventory: {
        scenes: [{ "sceneName" => "Clips" }],
        scene_items_by_scene: { "Clips" => [] }
      }
    )

    runtime = described_class.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: FakeSessionRunner.new(sessions: [session]),
      heartbeat_interval: 10.0,
      idle_sleep: 0.05,
      monotonic_clock: monotonic_clock,
      sleeper: sleeper
    )

    runtime.start!

    wait_until { state.runtime_connected? }
    first_calls = session.fetch_inventory_calls

    runtime.refresh_inventory!

    wait_until { session.fetch_inventory_calls > first_calls }
    expect(session.fetch_inventory_calls).to be >= 2

    runtime.stop!
    wait_until { !runtime.running? }
  end

  it "heartbeats while connected" do
    session = FakeSession.new(
      inventory: {
        scenes: [{ "sceneName" => "Clips" }],
        scene_items_by_scene: { "Clips" => [] }
      }
    )

    runtime = described_class.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: FakeSessionRunner.new(sessions: [session]),
      heartbeat_interval: 0.1,
      idle_sleep: 0.05,
      monotonic_clock: monotonic_clock,
      sleeper: sleeper
    )

    runtime.start!

    wait_until { state.runtime_connected? }
    first_heartbeat = status["last_heartbeat_at"]

    wait_until { status["last_heartbeat_at"] != first_heartbeat }

    runtime.stop!
    wait_until { !runtime.running? }
  end

  it "records runtime errors and retries" do
    session = FakeSession.new(
      inventory: {
        scenes: [{ "sceneName" => "Clips" }],
        scene_items_by_scene: { "Clips" => [] }
      },
      pump_error: StandardError.new("socket went sideways")
    )

    sleeps = []
    backoff = ObsBridge::Backoff.new(
      min: 0.01,
      max: 0.02,
      factor: 2.0,
      jitter: 0.0,
      sleeper: ->(seconds) { sleeps << seconds; sleeper.call(seconds) }
    )

    runner = FakeSessionRunner.new(
      sessions: [session, session]
    )

    runtime = described_class.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: runner,
      backoff: backoff,
      heartbeat_interval: 10.0,
      idle_sleep: 0.01,
      monotonic_clock: monotonic_clock,
      sleeper: sleeper
    )

    runtime.start!

    wait_until { status["last_error"] == "runtime loop failed: StandardError: socket went sideways" }
    wait_until { runner.run_calls >= 2 }

    expect(sleeps).not_to be_empty

    runtime.stop!
    wait_until { !runtime.running? }
  end

  it "marks the runtime down on stop" do
    session = FakeSession.new(
      inventory: {
        scenes: [{ "sceneName" => "Clips" }],
        scene_items_by_scene: { "Clips" => [] }
      }
    )

    runtime = described_class.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: FakeSessionRunner.new(sessions: [session]),
      heartbeat_interval: 10.0,
      idle_sleep: 0.05,
      monotonic_clock: monotonic_clock,
      sleeper: sleeper
    )

    runtime.start!
    wait_until { state.runtime_connected? }

    runtime.stop!
    wait_until { !runtime.running? }

    expect(status["runtime_state"]).to eq("down")
    expect(status["connected"]).to eq("false")
  end
end
