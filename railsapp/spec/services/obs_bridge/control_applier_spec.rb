# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::ControlApplier do
  let(:redis) { FakeRedis.new }
  let(:clock_state) { Struct.new(:now).new(Time.utc(2026, 3, 23, 18, 0, 0)) }
  let(:clock) { -> { clock_state.now } }
  let(:state) do
    ObsBridge::BridgeState.new(
      redis: redis,
      bridge_id: "main",
      clock: clock,
      default_enabled: false
    )
  end
  let(:signals) { [] }

  subject(:applier) do
    described_class.new(
      state: state,
      signal_queue: signals
    )
  end

  it "enables the bridge and signals reconcile" do
    result = applier.apply(
      ObsBridge::ControlMessage::Enable.new(bridge_id: "main", command_id: "abc")
    )

    expect(result).to eq(:enabled)
    expect(state.desired_enabled?).to be(true)
    expect(signals).to eq([ObsBridge::Cmd.reconcile])
  end

  it "disables the bridge and signals reconcile" do
    state.enable!

    result = applier.apply(
      ObsBridge::ControlMessage::Disable.new(bridge_id: "main", command_id: "abc")
    )

    expect(result).to eq(:disabled)
    expect(state.desired_enabled?).to be(false)
    expect(signals).to eq([ObsBridge::Cmd.reconcile])
  end

  it "starts a capture-all window without queueing a signal" do
    result = applier.apply(
      ObsBridge::ControlMessage::CaptureAll.new(
        bridge_id: "main",
        duration_seconds: 900,
        command_id: "abc"
      )
    )

    expect(result).to eq(:capture_all)
    expect(state.capture_all_active?).to be(true)
    expect(signals).to be_empty
  end

  it "signals refresh_inventory for refresh commands" do
    result = applier.apply(
      ObsBridge::ControlMessage::Refresh.new(bridge_id: "main", command_id: "abc")
    )

    expect(result).to eq(:refresh)
    expect(signals).to eq([ObsBridge::Cmd.refresh_inventory])
  end

  it "ignores commands for other bridges" do
    result = applier.apply(
      ObsBridge::ControlMessage::Ignored.new(
        bridge_id: "main",
        actual_bridge_id: "other",
        command_id: "abc"
      )
    )

    expect(result).to eq(:ignored)
    expect(state.desired_enabled?).to be(false)
    expect(signals).to be_empty
  end
end
