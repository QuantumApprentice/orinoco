# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::BridgeState do
  let(:redis) { FakeRedis.new }
  let(:clock_state) { Struct.new(:now).new(Time.utc(2026, 3, 23, 18, 0, 0)) }
  let(:clock) { -> { clock_state.now } }
  let(:keys) { ObsBridge::RedisKeys.new(bridge_id: "main") }

  subject(:state) do
    described_class.new(
      redis: redis,
      bridge_id: "main",
      clock: clock,
      default_enabled: false
    )
  end

  def status
    redis.hgetall(keys.status)
  end

  it "boots disabled and down, and projects that into redis" do
    expect(state.desired_enabled?).to be(false)
    expect(state.runtime_connected?).to be(false)
    expect(state.runtime_state).to eq("down")

    expect(status).to include(
      "bridge_id" => "main",
      "desired_state" => "disabled",
      "runtime_state" => "down",
      "connected" => "false",
      "capture_all_until" => "",
      "capture_all_active" => "false",
      "last_error" => "",
      "last_heartbeat_at" => "",
      "updated_at" => "2026-03-23T18:00:00.000000Z"
    )
  end

  it "can be enabled and disabled" do
    state.enable!
    expect(state.desired_enabled?).to be(true)
    expect(status["desired_state"]).to eq("enabled")

    state.disable!
    expect(state.desired_enabled?).to be(false)
    expect(status["desired_state"]).to eq("disabled")
  end

  it "tracks connection transitions" do
    state.connected!
    expect(state.runtime_connected?).to be(true)
    expect(state.runtime_state).to eq("up")
    expect(status["connected"]).to eq("true")
    expect(status["runtime_state"]).to eq("up")

    state.disconnected!(error: "OBS went away")
    expect(state.runtime_connected?).to be(false)
    expect(state.runtime_state).to eq("down")
    expect(status["connected"]).to eq("false")
    expect(status["runtime_state"]).to eq("down")
    expect(status["last_error"]).to eq("OBS went away")
  end

  it "records a capture window and reports activity while it is live" do
    state.capture_all_for(900)

    expect(state.capture_all_active?).to be(true)
    expect(status["capture_all_active"]).to eq("true")
    expect(Time.iso8601(status["capture_all_until"])).to eq(Time.utc(2026, 3, 23, 18, 15, 0))
  end

  it "extends a capture window rather than shrinking it" do
    state.capture_all_for(900)

    first_deadline = Time.iso8601(status["capture_all_until"])

    clock_state.now += 60
    state.capture_all_for(30)

    expect(Time.iso8601(status["capture_all_until"])).to eq(first_deadline)
  end

  it "shows capture-all as inactive after expiry once status is refreshed" do
    state.capture_all_for(900)

    clock_state.now += 901
    expect(state.capture_all_active?).to be(false)

    state.heartbeat!
    expect(status["capture_all_active"]).to eq("false")
  end

  it "can clear the capture window" do
    state.capture_all_for(900)
    state.clear_capture_all!

    expect(state.capture_all_active?).to be_nil
    expect(status["capture_all_until"]).to eq("")
    expect(status["capture_all_active"]).to eq("false")
  end

  it "records and clears errors" do
    state.set_last_error!("kaboom")
    expect(status["last_error"]).to eq("kaboom")

    state.clear_last_error!
    expect(status["last_error"]).to eq("")
  end

  it "records heartbeats" do
    state.heartbeat!
    expect(status["last_heartbeat_at"]).to eq("2026-03-23T18:00:00.000000Z")

    clock_state.now += 5
    state.heartbeat!
    expect(status["last_heartbeat_at"]).to eq("2026-03-23T18:00:05.000000Z")
  end

  it "rejects non-positive capture durations" do
    expect { state.capture_all_for(0) }.to raise_error(ArgumentError, /positive/)
    expect { state.capture_all_for(-5) }.to raise_error(ArgumentError, /positive/)
  end
end
