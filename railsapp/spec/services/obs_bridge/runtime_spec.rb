# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::Runtime do
  let(:state) do
    instance_double(
      ObsBridge::BridgeState,
      connected!: nil,
      heartbeat!: nil,
      disconnected!: nil
    )
  end

  let(:inventory_store) do
    instance_double(
      ObsBridge::InventoryStore,
      write_snapshot!: nil
    )
  end

  let(:session_runner) do
    instance_double(ObsBridge::ObswsRequestSessionRunner)
  end

  let(:backoff) do
    instance_double(
      ObsBridge::Backoff,
      reset!: nil,
      snooze!: nil
    )
  end

  let(:logger) { instance_double(Proc, call: nil) }

  let(:inventory) do
    {
      scenes: [{ "sceneName" => "Clips" }],
      scene_items_by_scene: {
        "Clips" => [{ "sceneItemId" => 1, "sourceName" => "fight", "sceneItemEnabled" => true }]
      }
    }
  end

  let(:mono_state) { Struct.new(:value).new(0.0) }
  let(:monotonic_clock) { -> { mono_state.value } }
  let(:sleeper) do
    lambda do |seconds|
      mono_state.value += seconds
      sleep(seconds / 50.0)
    end
  end

  let(:session) do
    double("obs session", fetch_inventory: inventory).tap do |sess|
      allow(sess).to receive(:pump_once) do |timeout:|
        mono_state.value += timeout
        sleep(timeout / 50.0)
      end
    end
  end

  let(:heartbeat_interval) { 10.0 }
  let(:idle_sleep) { 0.05 }

  let(:affordance_host) { instance_double(ObsBridge::AffordanceHost) }

  let(:inventory_reader) { instance_double(ObsBridge::InventoryReader) }
  let(:affordance_config_reader) { instance_double(ObsBridge::AffordanceConfigReader) }
  let(:obs_request_emitter) { instance_double(Proc) }

  let(:affordance_context) do
    instance_double(
      ObsBridge::AffordanceContext,
      inventory: inventory_reader,
      config: affordance_config_reader,
      emit_request: obs_request_emitter
    )
  end

  subject(:runtime) do
    described_class.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: session_runner,
      affordance_host: affordance_host,
      logger: logger,
      backoff: backoff,
      heartbeat_interval: heartbeat_interval,
      idle_sleep: idle_sleep,
      affordance_context: affordance_context
    )
  end

  def wait_until(timeout: 1.5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    loop do
      return true if yield
      raise "timed out waiting for condition" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  def eventually(timeout: 1.5)
    wait_until(timeout:) do
      yield
      true
    rescue RSpec::Expectations::ExpectationNotMetError
      false
    end
  end

  it "connects, heartbeats, and hydrates inventory on start" do
    allow(session_runner).to receive(:run).and_yield(session)

    runtime.start!

    eventually { expect(backoff).to have_received(:reset!) }
    eventually { expect(state).to have_received(:connected!) }
    eventually { expect(state).to have_received(:heartbeat!).at_least(:once) }
    eventually do
      expect(inventory_store).to have_received(:write_snapshot!).with(
        scenes: inventory[:scenes],
        scene_items_by_scene: inventory[:scene_items_by_scene]
      )
    end

    runtime.stop!
    wait_until { !runtime.running? }

    expect(state).to have_received(:disconnected!).at_least(:once)
  end

  it "refreshes inventory on demand while running" do
    allow(session_runner).to receive(:run).and_yield(session)

    runtime.start!

    eventually { expect(session).to have_received(:fetch_inventory).once }

    runtime.refresh_inventory!

    eventually { expect(session).to have_received(:fetch_inventory).at_least(:twice) }
    eventually { expect(inventory_store).to have_received(:write_snapshot!).at_least(:twice) }

    runtime.stop!
    wait_until { !runtime.running? }
  end

  it "does nothing when refresh_inventory! is called while stopped" do
    expect(runtime.refresh_inventory!).to be_nil
    expect(inventory_store).not_to have_received(:write_snapshot!)
  end

  it "heartbeats while connected" do
    allow(session_runner).to receive(:run).and_yield(session)

    runtime = described_class.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: session_runner,
      logger: logger,
      backoff: backoff,
      heartbeat_interval: 0.1,
      idle_sleep: 0.05,
      monotonic_clock: monotonic_clock,
      sleeper: sleeper
    )

    runtime.start!

    eventually { expect(state).to have_received(:heartbeat!).at_least(:twice) }

    runtime.stop!
    wait_until { !runtime.running? }
  end

  it "records runtime errors, disconnects with the error, and retries with backoff" do
    allow(session).to receive(:pump_once).and_raise(StandardError.new("socket went sideways"))
    allow(session_runner).to receive(:run).and_yield(session)

    runtime.start!

    eventually do
      expect(state).to have_received(:disconnected!)
        .with(error: "runtime loop failed: StandardError: socket went sideways")
        .at_least(:once)
    end

    eventually { expect(session_runner).to have_received(:run).at_least(:twice) }
    eventually { expect(backoff).to have_received(:snooze!).with(label: "obs-bridge/runtime").at_least(:once) }

    runtime.stop!
    wait_until { !runtime.running? }
  end

  it "marks disconnected on stop" do
    allow(session_runner).to receive(:run).and_yield(session)

    runtime.start!
    eventually { expect(state).to have_received(:connected!) }

    runtime.stop!
    wait_until { !runtime.running? }

    expect(state).to have_received(:disconnected!).at_least(:once)
  end

  it "raises if started twice" do
    allow(session_runner).to receive(:run).and_yield(session)

    runtime.start!
    wait_until { runtime.running? }

    expect { runtime.start! }.to raise_error("runtime already running")

    runtime.stop!
    wait_until { !runtime.running? }
  end

  it "sleeps instead of pumping when the session does not support pump_once" do
    session_without_pump = double("obs session", fetch_inventory: inventory)
    sleep_calls = []

    custom_sleeper = lambda do |seconds|
      sleep_calls << seconds
      mono_state.value += seconds
      sleep(seconds / 50.0)
    end

    allow(session_runner).to receive(:run).and_yield(session_without_pump)

    runtime.start!

    eventually do
      expect(inventory_store).to have_received(:write_snapshot!).with(
        scenes: inventory[:scenes],
        scene_items_by_scene: inventory[:scene_items_by_scene]
      )
    end

    wait_until { sleep_calls.include?(idle_sleep) }

    runtime.stop!
    wait_until { !runtime.running? }

    expect(sleep_calls).to include(idle_sleep)
  end
end
